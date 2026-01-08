package cli

import (
	"os"
	"os/signal"
	"syscall"
)

func waitForShutdown() {
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	<-sig
}
