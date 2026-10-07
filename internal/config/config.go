package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	ListenAddress           string
	PublicAPIURL            string
	PublicStorageURL        string
	PublicRegistryURL       string
	EnableInsecureDevAuth   bool
	RegistryUsername        string
	RegistryPassword        string
	RegistryRepositoryRoot  string
	ServerReadHeaderTimeout time.Duration
	ServerReadTimeout       time.Duration
	ServerWriteTimeout      time.Duration
	ServerIdleTimeout       time.Duration
	ServerShutdownTimeout   time.Duration
	ServerMaxHeaderBytes    int
	MaxJSONBodyBytes        int64
	MaxUploadBytes          int64
}

// Load reads the registry configuration from environment variables.
func Load() Config {
	return Config{
		ListenAddress: env("CHARM_REGISTRY_LISTEN", ":18080"),
		PublicAPIURL:  strings.TrimRight(env("CHARM_REGISTRY_PUBLIC_API_URL", "http://localhost:18080"), "/"),
		PublicStorageURL: strings.TrimRight(
			env("CHARM_REGISTRY_PUBLIC_STORAGE_URL", "http://localhost:18080"),
			"/",
		),
		PublicRegistryURL: strings.TrimRight(
			env("CHARM_REGISTRY_PUBLIC_REGISTRY_URL", "http://localhost:5000"),
			"/",
		),
		EnableInsecureDevAuth:   envBool("CHARM_REGISTRY_ENABLE_INSECURE_DEV_AUTH", true),
		RegistryUsername:        env("CHARM_REGISTRY_REGISTRY_USERNAME", "registry"),
		RegistryPassword:        env("CHARM_REGISTRY_REGISTRY_PASSWORD", "registry-secret"),
		RegistryRepositoryRoot:  strings.Trim(env("CHARM_REGISTRY_REGISTRY_REPOSITORY_ROOT", "charms"), "/"),
		ServerReadHeaderTimeout: envDuration("CHARM_REGISTRY_SERVER_READ_HEADER_TIMEOUT", 10*time.Second),
		ServerReadTimeout:       envDuration("CHARM_REGISTRY_SERVER_READ_TIMEOUT", 30*time.Second),
		ServerWriteTimeout:      envDuration("CHARM_REGISTRY_SERVER_WRITE_TIMEOUT", 30*time.Second),
		ServerIdleTimeout:       envDuration("CHARM_REGISTRY_SERVER_IDLE_TIMEOUT", 120*time.Second),
		ServerShutdownTimeout:   envDuration("CHARM_REGISTRY_SERVER_SHUTDOWN_TIMEOUT", 30*time.Second),
		ServerMaxHeaderBytes:    envInt("CHARM_REGISTRY_SERVER_MAX_HEADER_BYTES", 1<<20),
		MaxJSONBodyBytes:        envInt64("CHARM_REGISTRY_MAX_JSON_BODY_BYTES", 1<<20),
		MaxUploadBytes:          envInt64("CHARM_REGISTRY_MAX_UPLOAD_BYTES", 64<<20),
	}
}

func env(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		return fallback
	}
	return value
}

func envInt(key string, fallback int) int {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return value
}

func envInt64(key string, fallback int64) int64 {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	value, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return fallback
	}
	return value
}

func envDuration(key string, fallback time.Duration) time.Duration {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	value, err := time.ParseDuration(raw)
	if err != nil {
		return fallback
	}
	return value
}
