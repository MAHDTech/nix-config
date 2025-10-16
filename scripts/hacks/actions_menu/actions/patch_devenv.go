package actions

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"actions_menu/utils"

	tea "github.com/charmbracelet/bubbletea"
	"golang.org/x/sync/errgroup"
)

func init() {
	Register(ActionSpec{
		Title:       "Patch devenv excludes",
		Description: "Replace excludes in all devenv.nix files",
		Action:      RunPatch,
	})
}

// RunPatch processes a list of files to replace the excludes pattern.
func RunPatch(ch chan tea.Msg, yolo bool, logger *log.Logger) {
	var paths []string
	homeDir := os.Getenv("HOME")
	if homeDir == "" {
		ch <- ErrorMsg(fmt.Errorf("HOME environment variable not set"))
		return
	}
	// TODO: Put back after testing.
	//startDir := filepath.Join(homeDir, "Projects")
	startDir := filepath.Join(homeDir, "Projects", "test")
	if resolved, err := filepath.EvalSymlinks(startDir); err == nil {
		startDir = resolved
	}
	if _, err := os.Stat(startDir); os.IsNotExist(err) {
		ch <- ErrorMsg(fmt.Errorf("starting directory %s does not exist", startDir))
		return
	}

	logger = log.New(os.Stderr, "actions: ", log.LstdFlags)

	err := filepath.Walk(startDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			logger.Printf("Error accessing path %s: %v", path, err)
			return nil // Continue walking
		}
		logger.Printf("Walking: %s", path)
		if info.Mode()&os.ModeSymlink != 0 {
			if link, err := os.Readlink(path); err == nil {
				logger.Printf("Readlink: %s -> %s", path, link)
				var absLink string
				if strings.HasPrefix(link, "/") {
					absLink = link
				} else {
					absLink = filepath.Join(filepath.Dir(path), link)
					absLink, _ = filepath.Abs(absLink)
				}
				logger.Printf("AbsLink: %s", absLink)
				if stat, err := os.Stat(absLink); err != nil {
					logger.Printf("Stat failed: %v", err)
				} else if stat.IsDir() {
					logger.Printf("Following symlink to directory: %s", absLink)
					if err := filepath.Walk(absLink, func(p string, i os.FileInfo, e error) error {
						logger.Printf("Walking inner: %s", p)
						if e != nil {
							logger.Printf("Error in symlinked dir %s: %v", p, e)
							return nil
						}
						if i == nil {
							return nil
						}
						if !i.IsDir() && i.Name() == "devenv.nix" {
							logger.Printf("Found devenv.nix in symlinked dir: %s", p)
							paths = append(paths, p)
						}
						return nil
					}); err != nil {
						logger.Printf("Error walking symlinked dir %s: %v", absLink, err)
					}
				} else {
					logger.Printf("Not a dir: %s", absLink)
				}
			} else {
				logger.Printf("Readlink failed: %v", err)
			}
		}
		if !info.IsDir() && info.Name() == "devenv.nix" {
			logger.Printf("Found devenv.nix: %s", path)
			paths = append(paths, path)
		}
		return nil
	})
	if err != nil {
		ch <- ErrorMsg(fmt.Errorf("error walking directory: %v", err))
		return
	}

	g, ctx := errgroup.WithContext(context.Background())
	g.SetLimit(10) // Limit concurrency

	var mu sync.Mutex

	for _, path := range paths {
		path := path // capture loop variable
		g.Go(func() error {
			select {
			case <-ctx.Done():
				return ctx.Err()
			default:
				changed, diff, err := utils.ProcessFile(path, yolo, logger)
				mu.Lock()
				defer mu.Unlock()
				if err != nil {
					// We send the error but don't cancel the whole group
					ch <- ErrorMsg(err)
				} else {
					ch <- ProcessedMsg{}
					if changed {
						ch <- MatchedMsg(path)
						if !yolo && diff != "" {
							ch <- DiffMsg(diff)
						}
					}
				}
				return nil
			}
		})
	}

	// Wait for all goroutines to finish.
	// We don't act on the error here because errors are sent over the channel.
	_ = g.Wait()
	ch <- DoneMsg{}
	close(ch)
}
