package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
)

// Get the IP address from a randomly chosen VM Instance in an Managed Instance Group
// of the given name in the given region.
func getRandomPublicIPFromInstanceGroup(t *testing.T, projectID string, zone string, groupName string) (string, error) {
	instanceIds := gcp.GetInstanceIdsForInstanceGroup(t, projectID, zone, groupName)

	if len(instanceIds) == 0 {
		return "", fmt.Errorf("Could not find any instances in Instance Group %s in %s", groupName, zone)
	}

	return gcp.GetPublicIPOfInstance(t, projectID, zone, instanceIds[0]), nil
}
