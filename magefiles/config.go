package main

import (
	"github.com/google/go-jsonnet"
)

const (
	envKey = "environment"

	stageEnv      = "stage"
	productionEnv = "production"
	stageNS       = "rhobs-stage"
	productionNS  = "rhobs-production"

	vendorPath = "./vendor_jsonnet"
)

var vm = getVM()

func getVM() *jsonnet.VM {
	vm := jsonnet.MakeVM()
	vm.Importer(&jsonnet.FileImporter{
		JPaths: []string{
			vendorPath,
			"./config/",
			"./lib/",
		},
	})
	return vm
}
