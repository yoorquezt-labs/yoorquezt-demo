// solver — Competing intent solver for YoorQuezt MEV demo.
//
// Each solver instance registers with the MEV engine, generates intents,
// and competes to solve other solvers' intents. Uses Redis pub/sub for
// intent discovery so solvers are fully independent processes.
//
// Strategies:
//   speed  — submits fastest, lower output
//   price  — queries DEX, best output, slower
//   cross  — checks multiple chains, best cross-chain price
package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"github.com/yoorquezt-labs/yoorquezt-demo/internal/logger"
	"math/big"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
)

// ── Flags ───────────────────────────────────────────────────────────

var (
	strategy   = flag.String("strategy", "speed", "Solver strategy: speed, price, cross")
	name       = flag.String("name", "", "Solver display name (auto-generated if empty)")
	mevURL     = flag.String("mev", "http://mev-engine:9090", "MEV engine URL")
	token      = flag.String("token", "demo-token", "MEV API token")
	redisURL   = flag.String("redis", "redis://redis:6379", "Redis URL")
	interval   = flag.Duration("interval", 8*time.Second, "Intent generation interval")
	statusAddr = flag.String("status-addr", ":9200", "HTTP status listener")
)

// ── Types ───────────────────────────────────────────────────────────

type Intent struct {
	IntentID    string      `json:"intent_id,omitempty"`
	Type        string      `json:"type"`
	UserAddress string      `json:"user_address"`
	Chain       string      `json:"chain"`
	Deadline    int64       `json:"deadline"`
	SwapIntent  *SwapIntent `json:"swap_intent,omitempty"`
}

type SwapIntent struct {
	TokenIn        string `json:"token_in"`
	TokenOut       string `json:"token_out"`
	AmountIn       string `json:"amount_in"`
	MinAmountOut   string `json:"min_amount_out"`
	MaxSlippageBps int    `json:"max_slippage_bps"`
}

type Solution struct {
	SolutionID          string        `json:"solution_id,omitempty"`
	Bundle              BundleMessage `json:"bundle"`
	OutputAmount        string        `json:"output_amount"`
	Score               string        `json:"score"`
	SlippageBps         int           `json:"slippage_bps"`
	FillTimeMs          int64         `json:"fill_time_ms"`
	PriceImprovementBps int           `json:"price_improvement_bps"`
}

type BundleMessage struct {
	Type         string               `json:"type"`
	BundleID     string               `json:"bundle_id"`
	Transactions []TransactionMessage `json:"transactions"`
	Timestamp    int64                `json:"timestamp"`
	BidWei       string               `json:"bid_wei"`
}

type TransactionMessage struct {
	Type      string `json:"type"`
	TxID      string `json:"tx_id"`
	From      string `json:"from"`
	To        string `json:"to"`
	Chain     string `json:"chain"`
	Payload   string `json:"payload"`
	Timestamp int64  `json:"timestamp"`
	Value     string `json:"value,omitempty"`
}

type IntentStatusInfo struct {
	IntentID      string        `json:"intent_id"`
	Status        string        `json:"status"`
	BestSolution  *SolutionInfo `json:"best_solution,omitempty"`
	SolutionCount int           `json:"solution_count"`
}

type SolutionInfo struct {
	SolverID     string `json:"solver_id"`
	OutputAmount string `json:"output_amount"`
}

// ── Strategy configs ────────────────────────────────────────────────

type strategyConfig struct {
	displayName     string
	chains          []string
	baseOutputWei   *big.Int // base output per 1 ETH of input
	slippageBps     int
	fillTimeMs      int64
	priceImproveBps int
	jitterPct       int // % random variation on output
}

var strategies = map[string]strategyConfig{
	"speed": {
		displayName:     "SpeedSolver",
		chains:          []string{"ethereum"},
		baseOutputWei:   new(big.Int).Mul(big.NewInt(1800), big.NewInt(1e6)), // 1800 USDC (6 dec)
		slippageBps:     50,                                                  // 0.50% slippage (loose)
		fillTimeMs:      80,                                                  // fast fill
		priceImproveBps: 5,
		jitterPct:       3,
	},
	"price": {
		displayName:     "PriceSolver",
		chains:          []string{"ethereum", "base"},
		baseOutputWei:   new(big.Int).Mul(big.NewInt(1850), big.NewInt(1e6)), // 1850 USDC (better price)
		slippageBps:     10,                                                  // 0.10% (tight)
		fillTimeMs:      350,                                                 // slower
		priceImproveBps: 25,
		jitterPct:       5,
	},
	"cross": {
		displayName:     "CrossChainSolver",
		chains:          []string{"ethereum", "base", "arbitrum"},
		baseOutputWei:   new(big.Int).Mul(big.NewInt(1870), big.NewInt(1e6)), // 1870 USDC (cross-chain arb)
		slippageBps:     20,                                                  // moderate
		fillTimeMs:      600,                                                 // slowest (cross-chain)
		priceImproveBps: 40,
		jitterPct:       8,
	},
}

// ── Counters ────────────────────────────────────────────────────────

var (
	intentsGenerated atomic.Int64
	solutionsPosted  atomic.Int64
	solutionsWon     atomic.Int64
	errCount         atomic.Int64
)

// ── Main ────────────────────────────────────────────────────────────

func main() {
	logger.Init("info")
	defer logger.Sync()

	flag.Parse()

	cfg, ok := strategies[*strategy]
	if !ok {
		logger.Fatalf("unknown strategy %q (use speed, price, cross)", *strategy)
	}

	solverName := *name
	if solverName == "" {
		solverName = cfg.displayName
	}
	solverID := fmt.Sprintf("solver-%s-%s", *strategy, randHex(4))
	solverAddr := fmt.Sprintf("0x%s", randHex(20))

	logger.Infof("Solver starting: name=%s id=%s strategy=%s", solverName, solverID, *strategy)

	// Connect to Redis
	opts, err := redis.ParseURL(*redisURL)
	if err != nil {
		logger.Fatalf("redis URL: %v", err)
	}
	rdb := redis.NewClient(opts)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		logger.Fatalf("redis ping: %v", err)
	}
	logger.Info("Redis connected")

	// Register solver with MEV engine
	regBody, _ := json.Marshal(map[string]any{
		"solver_id":    solverID,
		"name":         solverName,
		"address":      solverAddr,
		"chains":       cfg.chains,
		"intent_types": []string{"swap"},
	})
	resp, err := mevPost("/solver/register", regBody)
	if err != nil {
		logger.Fatalf("solver register: %v", err)
	}
	logger.Infof("Registered: %s", resp)

	// Start status HTTP server
	go serveStatus(solverID)

	// Subscribe to Redis for intent broadcasts
	sub := rdb.Subscribe(ctx, "yq:intents")
	ch := sub.Channel()

	// Intent generation loop
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case <-time.After(jitterDuration(*interval, 30)):
				intentID, err := generateIntent(cfg)
				if err != nil {
					logger.Warnf("generate intent: %v", err)
					errCount.Add(1)
					continue
				}
				intentsGenerated.Add(1)
				// Broadcast to all solvers
				rdb.Publish(ctx, "yq:intents", fmt.Sprintf("%s|%s", solverID, intentID))
				logger.Infof("Published intent %s", intentID)
			}
		}
	}()

	// Solution loop — solve other solvers' intents
	go func() {
		for msg := range ch {
			parts := strings.SplitN(msg.Payload, "|", 2)
			if len(parts) != 2 {
				continue
			}
			originSolver, intentID := parts[0], parts[1]
			if originSolver == solverID {
				continue // don't solve our own intents
			}
			go func(iid string) {
				// Small strategy-dependent delay (simulates computation time)
				time.Sleep(time.Duration(cfg.fillTimeMs/2) * time.Millisecond)

				if err := solveIntent(solverID, iid, cfg); err != nil {
					if !strings.Contains(err.Error(), "404") {
						logger.Warnf("solve %s: %v", iid, err)
						errCount.Add(1)
					}
					return
				}
				solutionsPosted.Add(1)
				logger.Infof("Solved intent %s (strategy=%s)", iid, *strategy)

				// Check if we won after a short delay
				time.Sleep(2 * time.Second)
				checkWin(solverID, iid)
			}(intentID)
		}
	}()

	// Graceful shutdown
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
	logger.Infof("Shutting down: intents=%d solutions=%d wins=%d errors=%d",
		intentsGenerated.Load(), solutionsPosted.Load(), solutionsWon.Load(), errCount.Load())
	cancel()
}

// ── Intent Generation ───────────────────────────────────────────────

var tokenPairs = []struct {
	tokenIn, tokenOut, chain string
	amountIn                 string
}{
	{"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "ethereum", "1000000000000000000"},     // 1 WETH → USDC
	{"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "0xdAC17F958D2ee523a2206206994597C13D831ec7", "ethereum", "2000000000"},              // 2000 USDC → USDT
	{"0x4200000000000000000000000000000000000006", "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "base", "500000000000000000"},            // 0.5 WETH → USDC (Base)
	{"0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", "0xaf88d065e77c8cC2239327C5EDb3A432268e5831", "arbitrum", "2000000000000000000"},      // 2 WETH → USDC (Arb)
	{"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "0x6B175474E89094C44Da98b954EedeAC495271d0F", "ethereum", "500000000000000000"},       // 0.5 WETH → DAI
}

func generateIntent(cfg strategyConfig) (string, error) {
	pair := tokenPairs[randInt(len(tokenPairs))]

	// Filter by strategy chains
	chainOK := false
	for _, c := range cfg.chains {
		if c == pair.chain {
			chainOK = true
			break
		}
	}
	if !chainOK {
		pair = tokenPairs[0] // fallback to ethereum
	}

	intent := Intent{
		Type:        "swap",
		UserAddress: fmt.Sprintf("0x%s", randHex(20)),
		Chain:       pair.chain,
		Deadline:    time.Now().Add(60 * time.Second).Unix(),
		SwapIntent: &SwapIntent{
			TokenIn:        pair.tokenIn,
			TokenOut:       pair.tokenOut,
			AmountIn:       pair.amountIn,
			MinAmountOut:   "1",
			MaxSlippageBps: 100,
		},
	}

	body, _ := json.Marshal(intent)
	resp, err := mevPost("/intent", body)
	if err != nil {
		return "", err
	}

	var result map[string]string
	json.Unmarshal([]byte(resp), &result)
	return result["intent_id"], nil
}

// ── Solution Building ───────────────────────────────────────────────

func solveIntent(solverID, intentID string, cfg strategyConfig) error {
	// Fetch intent details
	intentData, err := mevGet(fmt.Sprintf("/intent/%s", intentID))
	if err != nil {
		return err
	}

	var status IntentStatusInfo
	if err := json.Unmarshal([]byte(intentData), &status); err != nil {
		return fmt.Errorf("parse intent: %w", err)
	}
	if status.Status != "pending" && status.Status != "solving" {
		return fmt.Errorf("intent %s not solvable (status=%s)", intentID, status.Status)
	}

	// Build solution with strategy-dependent output
	output := new(big.Int).Set(cfg.baseOutputWei)
	// Add random jitter
	jitter := new(big.Int).Div(output, big.NewInt(int64(100/cfg.jitterPct)))
	jitter.Mul(jitter, big.NewInt(int64(randInt(2*cfg.jitterPct)-cfg.jitterPct)))
	jitter.Div(jitter, big.NewInt(100))
	output.Add(output, jitter)

	bundleID := fmt.Sprintf("sol-bundle-%s-%s", *strategy, randHex(4))
	now := time.Now()

	sol := Solution{
		Bundle: BundleMessage{
			Type:     "bundle",
			BundleID: bundleID,
			Transactions: []TransactionMessage{
				{
					Type:      "transaction",
					TxID:      fmt.Sprintf("tx-%s-%s", *strategy, randHex(4)),
					From:      fmt.Sprintf("0x%s", randHex(20)),
					To:        fmt.Sprintf("0x%s", randHex(20)),
					Chain:     "ethereum",
					Payload:   fmt.Sprintf("0x%s", randHex(64)),
					Timestamp: now.UnixMilli(),
					Value:     "0",
				},
			},
			Timestamp: now.UnixMilli(),
			BidWei:    fmt.Sprintf("%d", 1e15+int64(randInt(1e15))), // 0.001-0.002 ETH bid
		},
		OutputAmount:        output.String(),
		Score:               output.String(),
		SlippageBps:         cfg.slippageBps + randInt(10),
		FillTimeMs:          cfg.fillTimeMs + int64(randInt(50)),
		PriceImprovementBps: cfg.priceImproveBps + randInt(5),
	}

	body, _ := json.Marshal(sol)
	req, err := http.NewRequest("POST", *mevURL+"/intent/"+intentID+"/solve", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+*token)
	req.Header.Set("X-Solver-ID", solverID)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("%d: %s", resp.StatusCode, string(b))
	}
	return nil
}

func checkWin(solverID, intentID string) {
	data, err := mevGet(fmt.Sprintf("/intent/%s", intentID))
	if err != nil {
		return
	}
	var status IntentStatusInfo
	if err := json.Unmarshal([]byte(data), &status); err != nil {
		return
	}
	if status.BestSolution != nil && status.BestSolution.SolverID == solverID {
		solutionsWon.Add(1)
		logger.Infof("WON intent %s (output=%s)", intentID, status.BestSolution.OutputAmount)
	}
}

// ── HTTP Helpers ────────────────────────────────────────────────────

func mevPost(path string, body []byte) (string, error) {
	req, err := http.NewRequest("POST", *mevURL+path, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+*token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(b))
	}
	return string(b), nil
}

func mevGet(path string) (string, error) {
	req, err := http.NewRequest("GET", *mevURL+path, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+*token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("%d: %s", resp.StatusCode, string(b))
	}
	return string(b), nil
}

// ── Status Server ───────────────────────────────────────────────────

func serveStatus(solverID string) {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"solver_id":         solverID,
			"strategy":          *strategy,
			"intents_generated": intentsGenerated.Load(),
			"solutions_posted":  solutionsPosted.Load(),
			"solutions_won":     solutionsWon.Load(),
			"errors":            errCount.Load(),
		})
	})
	logger.Infof("Status server on %s", *statusAddr)
	http.ListenAndServe(*statusAddr, mux)
}

// ── Utilities ───────────────────────────────────────────────────────

func randHex(n int) string {
	b := make([]byte, n)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func randInt(max int) int {
	if max <= 0 {
		return 0
	}
	b := make([]byte, 4)
	rand.Read(b)
	return int(uint32(b[0])<<24|uint32(b[1])<<16|uint32(b[2])<<8|uint32(b[3])) % max
}

func jitterDuration(base time.Duration, pct int) time.Duration {
	j := time.Duration(randInt(int(base) * pct / 100))
	return base + j - time.Duration(int(base)*pct/200)
}
