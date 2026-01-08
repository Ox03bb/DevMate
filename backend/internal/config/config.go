package config

type ConnectionInfo struct {
	Host string `json:"host"`
	Port int    `json:"port"`
	Name string `json:"name"`
}
