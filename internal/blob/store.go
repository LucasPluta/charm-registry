package blob

import (
	"context"
	"fmt"
	"sync"
)

type Store interface {
	Put(ctx context.Context, key string, payload []byte, contentType string) error
	Get(ctx context.Context, key string) ([]byte, error)
}

type MemoryStore struct {
	mu   sync.RWMutex
	data map[string][]byte
}

// NewMemoryStore returns an in-memory blob store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{data: map[string][]byte{}}
}

// Put is part of the [Store] interface.
func (s *MemoryStore) Put(_ context.Context, key string, payload []byte, _ string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data[key] = append([]byte(nil), payload...)
	return nil
}

// Get is part of the [Store] interface.
func (s *MemoryStore) Get(_ context.Context, key string) ([]byte, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	payload, ok := s.data[key]
	if !ok {
		return nil, fmt.Errorf("blob %q not found", key)
	}
	return append([]byte(nil), payload...), nil
}
