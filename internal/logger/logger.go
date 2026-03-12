package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var sugar *zap.SugaredLogger

func init() {
	Init("info")
}

func Init(level string) {
	var lvl zapcore.Level
	switch level {
	case "debug":
		lvl = zapcore.DebugLevel
	case "warn":
		lvl = zapcore.WarnLevel
	case "error":
		lvl = zapcore.ErrorLevel
	default:
		lvl = zapcore.InfoLevel
	}
	cfg := zap.Config{
		Level:            zap.NewAtomicLevelAt(lvl),
		Encoding:         "console",
		EncoderConfig:    zap.NewDevelopmentEncoderConfig(),
		OutputPaths:      []string{"stderr"},
		ErrorOutputPaths: []string{"stderr"},
	}
	l, err := cfg.Build()
	if err != nil {
		panic(err)
	}
	sugar = l.Sugar()
}

func Sync()                                              { _ = sugar.Sync() }
func Info(args ...interface{})                            { sugar.Info(args...) }
func Infof(template string, args ...interface{})         { sugar.Infof(template, args...) }
func Warn(args ...interface{})                           { sugar.Warn(args...) }
func Warnf(template string, args ...interface{})         { sugar.Warnf(template, args...) }
func Error(args ...interface{})                          { sugar.Error(args...) }
func Errorf(template string, args ...interface{})        { sugar.Errorf(template, args...) }
func Debug(args ...interface{})                          { sugar.Debug(args...) }
func Debugf(template string, args ...interface{})        { sugar.Debugf(template, args...) }
func Fatal(args ...interface{})                          { sugar.Fatal(args...) }
func Fatalf(template string, args ...interface{})        { sugar.Fatalf(template, args...) }
