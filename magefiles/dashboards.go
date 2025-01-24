package main

import (
	"fmt"
	"os"

	"github.com/ghodss/yaml"
	"github.com/google/go-jsonnet"
	"github.com/magefile/mage/mg"
)

const (
	vendorPath = "./vendor_jsonnet"

	dashboardSource = "./dashboards/"
	dashboardPath   = "./resources/dashboards/"
)

type (
	Dashboards mg.Namespace
)

// Alertmanager Generates the Alertmanager dashboard
func (d Dashboards) Alertmanager() error {
	const (
		filename = "alertmanager.jsonnet"
		fileOut  = "alertmanager.yaml"
	)

	vm := getVM()
	j, err := vm.EvaluateFile(getDashboardFile(filename))
	if err != nil {
		panic(err)
	}

	err = writeDashboardFile(fileOut, j)
	if err != nil {
		return fmt.Errorf("failed to write dashboard file: %w", err)
	}
	return nil
}

func getVM() *jsonnet.VM {
	vm := jsonnet.MakeVM()
	vm.Importer(&jsonnet.FileImporter{
		JPaths: []string{
			vendorPath,
		},
	})
	return vm
}

func getDashboardFile(filename string) string {
	return fmt.Sprint(dashboardSource, filename)
}

func writeDashboardFile(filename string, jsonContent string) error {
	b, err := yaml.JSONToYAML([]byte(jsonContent))
	if err != nil {
		return fmt.Errorf("failed to convert json to yaml: %w", err)
	}

	err = os.WriteFile(fmt.Sprint(dashboardPath, filename), b, 0644)
	if err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}
	return nil
}
