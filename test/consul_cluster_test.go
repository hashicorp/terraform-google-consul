package test

import (
	"testing"
)

// Test the example in the root folder
func TestConsulClusterWithUbuntuImage(t *testing.T) {
	t.Parallel()
	runConsulClusterTest(t, "googlecompute", ".", "../examples/consul-image/consul.json")
}
