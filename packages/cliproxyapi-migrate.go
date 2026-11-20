package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/router-for-me/CLIProxyAPI/v8/internal/config"
	"gopkg.in/yaml.v3"
)

func writeSynced(file *os.File, data []byte) error {
	if _, err := file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		file.Close()
		return err
	}
	return file.Close()
}

func migrate(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var document yaml.Node
	if err = yaml.Unmarshal(data, &document); err != nil {
		return err
	}
	if len(document.Content) != 1 || document.Content[0].Kind != yaml.MappingNode {
		return fmt.Errorf("config must be a mapping")
	}
	root := document.Content[0]
	for i := 0; i < len(root.Content); i += 2 {
		if root.Content[i].Value == "config-version" {
			version := root.Content[i+1]
			if version.Tag != "!!int" || version.Value != "8" {
				return fmt.Errorf("unsupported config version")
			}
			return nil
		}
	}
	for i := 0; i < len(root.Content); i += 2 {
		if root.Content[i].Value == "management" && root.Content[i+1].Tag == "!!null" {
			root.Content = append(root.Content[:i], root.Content[i+2:]...)
			break
		}
	}
	for i := 1; i < len(root.Content); i += 2 {
		if list := root.Content[i]; list.Kind == yaml.SequenceNode {
			list.Content = slices.DeleteFunc(list.Content, func(item *yaml.Node) bool {
				return item.Tag == "!!null"
			})
		}
	}
	converted, err := yaml.Marshal(&document)
	if err != nil {
		return err
	}
	config.SetV8MigrationWarnFunc(func(string, string) {})
	migrated, _, err := config.NormalizeConfigLayout(converted, true)
	if err != nil {
		return err
	}
	if _, err = config.ParseConfigBytes(migrated); err != nil {
		return err
	}
	backupPath := path + ".pre-v8." + time.Now().UTC().Format("20060102T150405.000000000Z")
	backup, err := os.OpenFile(backupPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	if err = writeSynced(backup, data); err != nil {
		return err
	}
	temp, err := os.CreateTemp(filepath.Dir(path), ".config-v8-*")
	if err != nil {
		return err
	}
	defer os.Remove(temp.Name())
	if err = writeSynced(temp, migrated); err != nil {
		return err
	}
	return os.Rename(temp.Name(), path)
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: config-migrate CONFIG")
		os.Exit(2)
	}
	if err := migrate(os.Args[1]); err != nil {
		fmt.Fprintln(os.Stderr, "CPA config migration failed; original configuration retained")
		os.Exit(1)
	}
}
