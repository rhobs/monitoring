package main

import (
	"os"
	"fmt"

	"github.com/ghodss/yaml"
	"github.com/google/go-jsonnet"
	"github.com/magefile/mage/mg"
)

const (
	alertsSource = "./alerts/"
	alertPath    = "./resources/alerts/"
)

var (
	envs = []string{stageEnv, productionEnv}
)

type (
	Alerts mg.Namespace
)

// Alertmanager Generates the Alertmanager alerts
func (a Alerts) Alertmanager() error {
	const (
		filename = "alertmanager.jsonnet"
		fileOut  = "alertmanager.yaml"
	)

	for _, env := range envs {
		v := buildAlertmanagerVM(env, vm)
		j, err := v.EvaluateFile(getAlertFile(filename))
		if err != nil {
			return fmt.Errorf("failed to evaluate file: %w", err)
		}

		err = writeAlertFile(env, fileOut, j)
		if err != nil {
			return fmt.Errorf("failed to write alert file: %w", err)
		}
	}
	return nil
}

func buildAlertmanagerVM(env string, vm *jsonnet.VM) *jsonnet.VM {
	switch e := env; {
	case e == stageEnv:
		vm.ExtVar(envKey, stageEnv)
		vm.ExtVar("selector", fmt.Sprintf(`job='alertmanager',namespace='%s'`, stageNS))
	case e == productionEnv:
		vm.ExtVar(envKey, productionEnv)
		vm.ExtVar("selector", fmt.Sprintf(`job='alertmanager',namespace='%s'`, productionNS))
	default:
		return vm
	}
	return vm
}

func getAlertFile(filename string) string {
	return fmt.Sprint(alertsSource, filename)
}

func writeAlertFile(env string, filename string, jsonContent string) error {
	b, err := yaml.JSONToYAML([]byte(jsonContent))
	if err != nil {
		return fmt.Errorf("failed to convert json to yaml: %w", err)
	}

	path := fmt.Sprintf("%s/%s/%s", alertPath, env, filename)
	err = os.WriteFile(path, b, 0644)
	if err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}
	return nil
}
