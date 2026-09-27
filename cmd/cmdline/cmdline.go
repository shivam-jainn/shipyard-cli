package cmdline

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/shivam-jainn/shipyard-cli/cmd/cmdline/commands"
	_ "github.com/shivam-jainn/shipyard-cli/cmd/cmdline/commands/init"
	_ "github.com/shivam-jainn/shipyard-cli/cmd/cmdline/commands/run"
	shiperrs "github.com/shivam-jainn/shipyard-core/pkg/errors"

	"github.com/spf13/cobra"
)

// Version is the current release version of Shipyard CLI.
// Can be overridden at build time via -ldflags or at runtime via SHIPYARD_VERSION env var.
var Version = "alpha 0.0.1"

// GetVersion returns the active Shipyard version, prioritizing the SHIPYARD_VERSION env var.
func GetVersion() string {
	if envVer := os.Getenv("SHIPYARD_VERSION"); envVer != "" {
		return envVer
	}
	return Version
}

var rootCmd = &cobra.Command{
	Use:           "shipyard",
	Short:         "shipyard CLI",
	Version:       GetVersion(),
	SilenceErrors: true,
}

func init() {
	rootCmd.Version = GetVersion()
	rootCmd.AddCommand(&cobra.Command{
		Use:   "version",
		Short: "Print the shipyard version",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("shipyard version %s\n", GetVersion())
		},
	})
}

func CmdLine() {
	rootCmd.Version = GetVersion()
	commands.AttachAll(rootCmd)

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	if err := rootCmd.ExecuteContext(ctx); err != nil {
		if sErr, ok := err.(*shiperrs.ShipyardError); ok {
			fmt.Fprintln(os.Stderr, sErr.FormatColored())
		} else {
			fmt.Fprintln(os.Stderr, err)
		}
		os.Exit(1)
	}
}
