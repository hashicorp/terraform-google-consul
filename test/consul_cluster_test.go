package test

import (
	"testing"
)

// Test the example in the root folder for Ubuntu 18.04
func TestConsulClusterWithUbuntu18Image(t *testing.T) {
	t.Parallel()

	// Uncomment any of the following to skip that section during the test
	//os.Setenv("SKIP_setup_image", "true")
	//os.Setenv("SKIP_deploy", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_build_2nd_image", "true")
	//os.Setenv("SKIP_redeploy_cluster", "true")
	//os.Setenv("SKIP_validate_key_exists", "true")
	//os.Setenv("SKIP_teardown", "true")
	//os.Setenv("SKIP_cleanup_images", "true")

	runConsulClusterTest(t, "ubuntu-18-image", ".", "../examples/consul-image/consul.json")
}
