package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"go.etcd.io/bbolt"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

var (
	tasksBucket = []byte("tasks")
	metaBucket  = []byte("meta")
	schemaKey   = []byte("schema_version")
)

const schemaVersion = "1"

type BoltTaskStore struct {
	db        *bbolt.DB
	closeOnce sync.Once
	closeErr  error
}

func OpenBoltTaskStore(path string) (*BoltTaskStore, error) {
	if !filepath.IsAbs(path) {
		return nil, fmt.Errorf("%w: database path must be absolute", download.ErrTaskPersistence)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, fmt.Errorf("%w: create data directory", download.ErrTaskPersistence)
	}
	db, err := bbolt.Open(path, 0o600, &bbolt.Options{Timeout: time.Second})
	if err != nil {
		return nil, fmt.Errorf("%w: open task database", download.ErrTaskPersistence)
	}
	if err = os.Chmod(path, 0o600); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("%w: secure task database", download.ErrTaskPersistence)
	}
	store := &BoltTaskStore{db: db}
	if err = db.Update(func(tx *bbolt.Tx) error {
		meta, createErr := tx.CreateBucketIfNotExists(metaBucket)
		if createErr != nil {
			return createErr
		}
		version := meta.Get(schemaKey)
		if version != nil && string(version) != schemaVersion {
			return fmt.Errorf("unsupported schema version %q", version)
		}
		if err = meta.Put(schemaKey, []byte(schemaVersion)); err != nil {
			return err
		}
		_, err = tx.CreateBucketIfNotExists(tasksBucket)
		return err
	}); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("%w: initialize task database: %v", download.ErrTaskPersistence, err)
	}
	return store, nil
}

func (s *BoltTaskStore) Load(ctx context.Context) ([]download.StoredTask, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	records := make([]download.StoredTask, 0)
	err := s.db.View(func(tx *bbolt.Tx) error {
		bucket := tx.Bucket(tasksBucket)
		if bucket == nil {
			return errors.New("tasks bucket is missing")
		}
		return bucket.ForEach(func(key, value []byte) error {
			if err := ctx.Err(); err != nil {
				return err
			}
			var record download.StoredTask
			if err := json.Unmarshal(value, &record); err != nil {
				return fmt.Errorf("decode task %q: %w", key, err)
			}
			if record.Task.ID == "" || record.Task.ID != string(key) {
				return fmt.Errorf("task %q has an invalid identifier", key)
			}
			records = append(records, record)
			return nil
		})
	})
	if err != nil {
		return nil, fmt.Errorf("%w: load tasks: %v", download.ErrTaskPersistence, err)
	}
	return records, nil
}

func (s *BoltTaskStore) Save(ctx context.Context, record download.StoredTask) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if record.Task.ID == "" {
		return fmt.Errorf("%w: task ID is required", download.ErrTaskPersistence)
	}
	value, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("%w: encode task", download.ErrTaskPersistence)
	}
	if err = s.db.Update(func(tx *bbolt.Tx) error {
		if err := ctx.Err(); err != nil {
			return err
		}
		bucket := tx.Bucket(tasksBucket)
		if bucket == nil {
			return errors.New("tasks bucket is missing")
		}
		return bucket.Put([]byte(record.Task.ID), value)
	}); err != nil {
		return fmt.Errorf("%w: save task", download.ErrTaskPersistence)
	}
	return nil
}

func (s *BoltTaskStore) Close() error {
	s.closeOnce.Do(func() {
		s.closeErr = s.db.Close()
	})
	return s.closeErr
}

var _ download.TaskStore = (*BoltTaskStore)(nil)
