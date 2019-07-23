package test

import (
	"testing"
)

// Test the example in the root folder for Ubuntu 16.04
func TestConsulClusterWithUbuntu16Image(t *testing.T) {
	t.Parallel()
	runConsulClusterTest(t, "ubuntu-16-image", ".", "../examples/consul-image/consul.json")
}

// Test the example in the root folder for Ubuntu 18.04
func TestConsulClusterWithUbuntu18Image(t *testing.T) {
	t.Parallel()
	runConsulClusterTest(t, "ubuntu-18-image", ".", "../examples/consul-image/consul.json")
}
