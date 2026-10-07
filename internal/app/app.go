package app

import (
	"net/http"

	"github.com/gschiano/charm-registry/internal/api"
	"github.com/gschiano/charm-registry/internal/auth"
	"github.com/gschiano/charm-registry/internal/blob"
	"github.com/gschiano/charm-registry/internal/config"
	"github.com/gschiano/charm-registry/internal/repo"
	"github.com/gschiano/charm-registry/internal/service"
)

type App struct {
	Handler http.Handler
}

// New wires the application dependencies and returns a ready HTTP app.
// All state lives in memory and is discarded when the process exits.
func New(cfg config.Config) *App {
	storage := blob.NewMemoryStore()
	repository := repo.NewMemory()
	authenticator := auth.New(cfg, repository)
	svc := service.New(cfg, repository, storage)
	handler := api.New(cfg, svc, authenticator)
	return &App{Handler: handler}
}
