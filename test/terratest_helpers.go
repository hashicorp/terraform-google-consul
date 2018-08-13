package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/packer"
)

// ConsulImageTemplateVarProjectID represents the Project ID variable in the Packer template
const ConsulImageTemplateVarProjectID = "project_id"

// ConsulImageTemplateVarZone represents the Zone variable in the Packer template
const ConsulImageTemplateVarZone = "zone"

// Use Packer to build the Image in the given Packer template, with the given build name and return the Image ID.
func buildImage(t *testing.T, packerTemplatePath string, packerBuildName string, gcpProjectID string, gcpZone string) string {
	options := &packer.Options{
		Template: packerTemplatePath,
		Only:     packerBuildName,
		Vars: map[string]string{
			ConsulImageTemplateVarProjectID: gcpProjectID,
			ConsulImageTemplateVarZone:      gcpZone,
		},
	}

	return packer.BuildArtifact(t, options)
}
