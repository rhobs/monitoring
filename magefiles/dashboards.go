package main

import (
	"fmt"
	"os"

	"github.com/ghodss/yaml"
	"github.com/magefile/mage/mg"
)

const (
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
		fileOut  = "alertmanager.configmap.yaml"
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

// Query Generates the Thanos Query dashboard
func (d Dashboards) Query() error {
	const (
		filename = "query.jsonnet"
		fileOut  = "thanos-query.configmap.yaml"
	)

	//vm := getVM()
	//j, err := vm.EvaluateFile(getDashboardFile(filename))
	//if err != nil {
	//	panic(err)
	//}
	//
	//err = writeDashboardFile(fileOut, j)
	//if err != nil {
	//	return fmt.Errorf("failed to write dashboard file: %w", err)
	//}
	// todo
	return nil
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
