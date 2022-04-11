package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/muesli/coral"
)

var rootCmd = &coral.Command{
	Use:     "skeleton",
	Short:   "Skeleton App, a bare bones Go cli app",
	Version: "0.0.1",
	Args:    coral.MaximumNArgs(1),
	Run: func(cmd *coral.Command, args []string) {
		startDir := cmd.Flags().Lookup("start-dir")
		selectionPath := cmd.Flags().Lookup("selection-path")

		log.Println(startDir)
		log.Println(selectionPath)
	},
}

// Execute runs the root command and starts the application.
func Execute() {
	rootCmd.AddCommand(updateCmd)
	rootCmd.PersistentFlags().String("selection-path", "", "Path to write to file on open.")
	rootCmd.PersistentFlags().String("start-dir", "", "Starting directory for FM")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
