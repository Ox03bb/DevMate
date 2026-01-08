package qrcode

import (
	"encoding/json"
	"fmt"

	cfg "devmate-backend/internal/config"

	qr "github.com/skip2/go-qrcode"
)

// Display generates and displays a QR code in the terminal
func Display(info cfg.ConnectionInfo) error {
	// Convert connection info to JSON
	jsonData, err := json.Marshal(info)
	if err != nil {
		return err
	}

	// Generate QR code
	code, err := qr.New(string(jsonData), qr.Medium)
	if err != nil {
		return err
	}

	// Convert to ASCII art
	asciiArt := code.ToSmallString(false)

	fmt.Println("[+] Scan this QR code to connect:")
	fmt.Println("┌" + string(make([]byte, 60)) + "┐")
	for _, line := range []rune(asciiArt) {
		if line == '\n' {
			fmt.Println()
		} else {
			fmt.Printf("%c", line)
		}
	}
	fmt.Println("└" + string(make([]byte, 60)) + "┘")

	return nil
}
