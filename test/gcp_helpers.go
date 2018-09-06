package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/robmorgan/terratest/modules/random"
)

// Get the IP address from a randomly chosen VM Instance in an Managed Instance Group
// of the given name in the given region.
func getRandomPublicIPFromInstanceGroup(t *testing.T, projectID string, zone string, groupName string) (string, error) {
	randNodeIndex := random.Random(1, ConsulClusterExampleDefaultNumServers)
	instanceIDs := gcp.GetInstanceIdsForInstanceGroup(t, projectID, zone, groupName)

	if randNodeIndex > len(instanceIDs) {
		return "", fmt.Errorf("Could not find any instances in Instance Group %s in %s", groupName, zone)
	}

	instanceID := instanceIDs[randNodeIndex-1]
	ip := gcp.GetPublicIPOfInstance(t, projectID, zone, instanceID)

	return ip, nil
}
