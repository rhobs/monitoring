package main

import (
	"fmt"
	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
)

type (
	Update mg.Namespace
)

// Alertmanager Updates the Alertmanager mixin
func (Update) Alertmanager() error {
	err := sh.Run("jb", "update", "github.com/prometheus/alertmanager/doc/alertmanager-mixin@main", `--jsonnetpkg-home=vendor_jsonnet`)
	if err != nil {
		fmt.Errorf("failed to update alertmanager mixin: %w", err)
	}
	return nil
}
