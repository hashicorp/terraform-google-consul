package test

import (
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/hashicorp/consul/api"
	"github.com/stretchr/testify/require"
)

var (
	// RepoRoot represents the root of the project.
	RepoRoot = "../"

	ConsulClusterExampleVarProject = "gcp_project_id"
	ConsulClusterExampleVarRegion  = "gcp_region"

	ConsulClusterExampleVarServerClusterName = "consul_server_cluster_name"
	ConsulClusterExampleVarClientClusterName = "consul_client_cluster_name"

	ConsulClusterExampleVarServerClusterTagName = "consul_server_cluster_tag_name"
	ConsulClusterExampleVarClientClusterTagName = "consul_client_cluster_tag_name"

	ConsulClusterExampleVarServerSourceImage = "consul_server_source_image"
	ConsulClusterExampleVarClientSourceImage = "consul_client_source_image"

	ConsulClusterExampleVarServerClusterSize = "consul_server_cluster_size"
	ConsulClusterExampleVarClientClusterSize = "consul_client_cluster_size"

	ConsulClusterExampleDefaultNumServers = 3
	ConsulClusterExampleDefaultNumClients = 4

	ConsulClusterExampleOutputServerInstanceGroupName = "instance_group_name"
	ConsulClusterExampleOutputClientInstanceGroupName = "client_instance_group_name"

	ConsulClusterServerAllowedInboundCidrBlockHttpApi = "consul_server_allowed_inbound_cidr_blocks_http_api"
	ConsulClusterServerAllowedInboundCidrBlockDns     = "consul_server_allowed_inbound_cidr_blocks_dns"

	ConsulClusterClientAllowedInboundCidrBlockHttpApi = "consul_client_allowed_inbound_cidr_blocks_http_api"
	ConsulClusterClientAllowedInboundCidrBlockDns     = "consul_client_allowed_inbound_cidr_blocks_dns"

	// Terratest var names
	GcpProjectIdVarName = "GCPProjectID"
	GcpRegionVarName    = "GCPRegion"
	GcpZoneVarName      = "GCPZone"
)

// Test the consul-cluster example by:
//
// 1. Copying the code in this repo to a temp folder so tests on the Terraform code can run in parallel without the
//    state files overwriting each other.
// 2. Building the Image in the consul-image example with the given build name
// 3. Deploying that Image using the consul-cluster Terraform code
// 4. Checking that the Consul cluster comes up within a reasonable time period and can respond to requests
// 5. Writing a random key to the KV store using one of the Consul clients
// 6. Building a new Image using the consul-image example with the given build name
// 7. Redeploying both of the cluster instance groups using the new image
// 8. Validating the rolling deployment by verifying the key was propagated correctly
func runConsulClusterTest(t *testing.T, packerBuildName string, examplesFolder string, packerTemplatePath string) {
	exampleFolder := test_structure.CopyTerraformFolderToTemp(t, RepoRoot, examplesFolder)

	test_structure.RunTestStage(t, "setup_image", func() {
		// Get the Project Id to use
		gcpProjectID := gcp.GetGoogleProjectIDFromEnvVar(t)

		// Pick a random GCP region to test in. This helps ensure your code works in all regions and zones.
		gcpRegion := gcp.GetRandomRegion(t, gcpProjectID, nil, nil)
		gcpZone := gcp.GetRandomZoneForRegion(t, gcpProjectID, gcpRegion)

		test_structure.SaveString(t, exampleFolder, GcpProjectIdVarName, gcpProjectID)
		test_structure.SaveString(t, exampleFolder, GcpRegionVarName, gcpRegion)
		test_structure.SaveString(t, exampleFolder, GcpZoneVarName, gcpZone)

		// Make sure the Packer build completes successfully
		imageID := buildImage(t, packerTemplatePath, packerBuildName, gcpProjectID, gcpZone)
		test_structure.SaveArtifactID(t, exampleFolder, imageID)
	})

	defer test_structure.RunTestStage(t, "cleanup_images", func() {
		projectID := test_structure.LoadString(t, exampleFolder, GcpProjectIdVarName)
		imageName := test_structure.LoadArtifactID(t, exampleFolder)
		secondImageName := test_structure.LoadString(t, exampleFolder, "Artifact2")
		image1 := gcp.FetchImage(t, projectID, imageName)
		image2 := gcp.FetchImage(t, projectID, secondImageName)
		defer image1.DeleteImage(t)
		defer image2.DeleteImage(t)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		gcpProjectID := test_structure.LoadString(t, exampleFolder, GcpProjectIdVarName)
		gcpRegion := test_structure.LoadString(t, exampleFolder, GcpRegionVarName)

		// GCP only supports lowercase names for some resources
		uniqueID := strings.ToLower(random.UniqueId())
		serverClusterName := fmt.Sprintf("consul-server-cluster-%s", uniqueID)
		clientClusterName := fmt.Sprintf("consul-client-cluster-%s", uniqueID)
		imageID := test_structure.LoadArtifactID(t, exampleFolder)

		terraformOptions := &terraform.Options{
			TerraformDir: exampleFolder,
			Vars: map[string]interface{}{
				ConsulClusterExampleVarProject:                    gcpProjectID,
				ConsulClusterExampleVarRegion:                     gcpRegion,
				ConsulClusterExampleVarServerClusterName:          serverClusterName,
				ConsulClusterExampleVarClientClusterName:          clientClusterName,
				ConsulClusterExampleVarServerClusterTagName:       serverClusterName,
				ConsulClusterExampleVarClientClusterTagName:       clientClusterName,
				ConsulClusterExampleVarServerSourceImage:          imageID,
				ConsulClusterExampleVarClientSourceImage:          imageID,
				ConsulClusterExampleVarServerClusterSize:          ConsulClusterExampleDefaultNumServers,
				ConsulClusterExampleVarClientClusterSize:          ConsulClusterExampleDefaultNumClients,
				ConsulClusterServerAllowedInboundCidrBlockHttpApi: []string{"0.0.0.0/0"},
				ConsulClusterServerAllowedInboundCidrBlockDns:     []string{"0.0.0.0/0"},
				ConsulClusterClientAllowedInboundCidrBlockHttpApi: []string{"0.0.0.0/0"},
				ConsulClusterClientAllowedInboundCidrBlockDns:     []string{"0.0.0.0/0"},
			},
		}
		test_structure.SaveTerraformOptions(t, exampleFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		gcpProjectID := test_structure.LoadString(t, exampleFolder, GcpProjectIdVarName)
		gcpRegion := test_structure.LoadString(t, exampleFolder, GcpRegionVarName)

		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)

		// Check the Consul servers
		checkConsulClusterIsWorking(t, ConsulClusterExampleOutputServerInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion)

		// Check the Consul clients
		checkConsulClusterIsWorking(t, ConsulClusterExampleOutputClientInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion)

		// Write a random KV store key to one of the clients
		randomKeyName := writeConsulClusterKVStore(t, ConsulClusterExampleOutputClientInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion)

		test_structure.SaveString(t, exampleFolder, "RandomKeyName", randomKeyName)
	})

	test_structure.RunTestStage(t, "build_2nd_image", func() {
		projectID := test_structure.LoadString(t, exampleFolder, GcpProjectIdVarName)
		gcpZone := test_structure.LoadString(t, exampleFolder, GcpZoneVarName)

		// Build a new image in the same zone
		imageID := buildImage(t, packerTemplatePath, packerBuildName, projectID, gcpZone)
		test_structure.SaveString(t, exampleFolder, "Artifact2", imageID)
	})

	test_structure.RunTestStage(t, "redeploy_cluster", func() {
		newImage := test_structure.LoadString(t, exampleFolder, "Artifact2")
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)

		// Switch the two instance groups to use the new image
		terraformOptions.Vars[ConsulClusterExampleVarServerSourceImage] = newImage
		terraformOptions.Vars[ConsulClusterExampleVarClientSourceImage] = newImage
		test_structure.SaveTerraformOptions(t, exampleFolder, terraformOptions)

		// Redeploy the cluster by running Terraform apply
		terraform.Apply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_key_exists", func() {
		gcpProjectID := test_structure.LoadString(t, exampleFolder, GcpProjectIdVarName)
		gcpRegion := test_structure.LoadString(t, exampleFolder, GcpRegionVarName)
		keyName := test_structure.LoadString(t, exampleFolder, "RandomKeyName")

		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)

		// Check the Consul servers
		checkConsulClusterIsWorking(t, ConsulClusterExampleOutputServerInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion)

		// Check the Consul clients
		checkConsulClusterIsWorking(t, ConsulClusterExampleOutputClientInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion)

		// Read the KV store key using one of the clients
		checkConsulClusterKVStoreHasKey(t, ConsulClusterExampleOutputClientInstanceGroupName, terraformOptions, gcpProjectID, gcpRegion, keyName)
	})
}

// Check that the Consul cluster comes up within a reasonable time period and can respond to requests
func checkConsulClusterIsWorking(t *testing.T, groupNameOutputVar string, terratestOptions *terraform.Options, projectID string, region string) {
	groupName := terraform.OutputRequired(t, terratestOptions, groupNameOutputVar)

	// It can take a few minutes for the managed instance group to boot up
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second

	// Check every 5 seconds until an instance has joined the managed instance group
	ip := retry.DoWithRetry(t, fmt.Sprintf("Waiting for instances in group %s", groupName), maxRetries, timeBetweenRetries, func() (string, error) {
		ip, err := getPublicIPFromRandomInstanceE(t, projectID, region, groupName)
		if err != nil {
			return "", err
		}

		return ip, nil
	})

	logger.Logf(t, "Consul cluster is working correctly. Got member IP: %s", ip)
	testConsulCluster(t, projectID, region, groupName)
}

// Pick a random node from the Consul cluster and use it to verify that:
//
// 1. The Consul cluster has deployed
// 2. The cluster has the expected number of nodes
// 3. The cluster has elected a leader
//
// Note: We must pick a random node each time as nodes may be removed during
// the rolling deployment or a new leader needs to be elected.
func testConsulCluster(t *testing.T, projectID string, region string, groupName string) {
	maxRetries := 60
	sleepBetweenRetries := 10 * time.Second
	expectedNodes := ConsulClusterExampleDefaultNumClients + ConsulClusterExampleDefaultNumServers

	leader := retry.DoWithRetry(t, "Check Consul nodes", maxRetries, sleepBetweenRetries, func() (string, error) {
		nodeIPAddress, err := getPublicIPFromRandomInstanceE(t, projectID, region, groupName)
		if err != nil {
			return "", err
		}

		// Create a Consul Client to query the available node
		consulClient := createConsulClient(t, nodeIPAddress)

		nodes, _, err := consulClient.Catalog().Nodes(nil)
		if err != nil {
			return "", err
		}

		if len(nodes) != expectedNodes {
			return "", fmt.Errorf("Expected the cluster to have %d nodes, but found %d", expectedNodes, len(nodes))
		}

		leader, err := consulClient.Status().Leader()
		if err != nil {
			return "", err
		}

		if leader == "" {
			return "", errors.New("Consul cluster returned an empty leader response, so a leader must not have been elected yet")
		}

		return leader, nil
	})

	logger.Logf(t, "Consul cluster is properly deployed and has elected leader %s", leader)
}

func getPublicIPFromRandomInstanceE(t *testing.T, projectID string, region string, groupName string) (string, error) {
	instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectID, region, groupName)

	instance, err := instanceGroup.GetRandomInstanceE(t)
	if err != nil {
		return "", err
	}

	ip, err := instance.GetPublicIpE(t)
	if err != nil {
		return "", err
	}

	return ip, nil
}

func writeConsulClusterKVStore(t *testing.T, groupNameOutputVar string, terratestOptions *terraform.Options, projectID string, region string) string {
	groupName := terraform.OutputRequired(t, terratestOptions, groupNameOutputVar)

	// get a random instance from the consul clients instance group
	instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectID, region, groupName)
	instance, err := instanceGroup.GetRandomInstanceE(t)
	require.NoError(t, err)

	ip, err := instance.GetPublicIpE(t)
	require.NoError(t, err)

	consulClient := createConsulClient(t, ip)

	// Get a handle to the KV API
	kv := consulClient.KV()

	// PUT a new KV pair
	uniqueID := strings.ToLower(random.UniqueId())
	randomKeyName := fmt.Sprintf("random-key-%s", uniqueID)
	logger.Logf(t, "Writing random key %s to the Consul client %s", randomKeyName, ip)
	p := &api.KVPair{Key: randomKeyName, Value: []byte("bar")}
	_, err = kv.Put(p, nil)
	require.NoError(t, err)

	return randomKeyName
}

func checkConsulClusterKVStoreHasKey(t *testing.T, groupNameOutputVar string, terratestOptions *terraform.Options, projectID string, region string, keyName string) {
	groupName := terraform.OutputRequired(t, terratestOptions, groupNameOutputVar)

	// get a random instance from the consul clients instance group
	instanceGroup := gcp.FetchRegionalInstanceGroup(t, projectID, region, groupName)
	instance, err := instanceGroup.GetRandomInstanceE(t)
	require.NoError(t, err)

	ip, err := instance.GetPublicIpE(t)
	require.NoError(t, err)

	consulClient := createConsulClient(t, ip)

	// Get a handle to the KV API
	kv := consulClient.KV()

	// Verify the given key exists
	pair, _, err := kv.Get(keyName, nil)
	require.NoError(t, err)
	logger.Logf(t, "Successfully verified target key %s has propagated with value: %s", keyName, pair.Value)
}

// Create a Consul client
func createConsulClient(t *testing.T, ipAddress string) *api.Client {
	config := api.DefaultConfig()
	config.Address = fmt.Sprintf("%s:8500", ipAddress)

	client, err := api.NewClient(config)
	if err != nil {
		t.Fatalf("Failed to create Consul client due to error: %v", err)
	}

	return client
}
