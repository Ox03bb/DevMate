package mdns

import (
	"fmt"

	cfg "devmate-backend/internal/config"

	"github.com/grandcat/zeroconf"
)

// Start creates and starts an mDNS server
func Start(hostname, ip string, port int) (*zeroconf.Server, error) {
	server, err := zeroconf.Register(
		hostname,          // instance name
		cfg.ServiceName,   // service type
		cfg.ServiceDomain, // domain
		port,              // port
		[]string{ // TXT records
			fmt.Sprintf("host=%s", ip),
			fmt.Sprintf("version=1.0"),
		},
		nil, // interfaces (nil = all)
	)
	if err != nil {
		return nil, err
	}

	return server, nil
}
