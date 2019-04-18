package test

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

type Disk struct {
	Name       string
	Fstype     string
	Label      string
	Mountpoint string
}

type LsblkOutput struct {
	Blockdevices []Disk
}

// TestTerraformEbsAttachModule will test default SSM document functionality
func TestTerraformEbsAttachModule(t *testing.T) {
	t.Parallel()

	exampleFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "example")

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)
		terraform.Destroy(t, terraformOptions)

		keyPair := test_structure.LoadEc2KeyPair(t, exampleFolder)
		aws.DeleteEC2KeyPair(t, keyPair)

	})

	// Deploy the example
	test_structure.RunTestStage(t, "setup", func() {
		terraformOptions, keyPair := configureTerraformOptions(t, exampleFolder)

		// Save the options and key pair so later test stages can use them
		test_structure.SaveTerraformOptions(t, exampleFolder, terraformOptions)
		test_structure.SaveEc2KeyPair(t, exampleFolder, keyPair)

		// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
		terraform.InitAndApply(t, terraformOptions)

		// Grab asg name from terrafrom output
		asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")

		// Grab region name from terrafrom output
		awsRegion := terraform.OutputRequired(t, terraformOptions, "aws_region")

		// Wait for instances to get provisioned
		aws.WaitForCapacity(t, asgName, awsRegion, 360, 1)

		// Get an instance ID in the asg
		instanceID := aws.GetInstanceIdsForAsg(t, asgName, awsRegion)

		// Get instance's public IP address
		publicIP := aws.GetPublicIpOfEc2Instance(t, instanceID[0], awsRegion)

		// Save instance's IP into file for further tests
		test_structure.SaveString(t, exampleFolder, "publicIP", publicIP)

	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleFolder)
		keyPair := test_structure.LoadEc2KeyPair(t, exampleFolder)
		publicIP := test_structure.LoadString(t, exampleFolder, "publicIP")

		testHostDisks(t, terraformOptions, keyPair, publicIP)
	})

}

func configureTerraformOptions(t *testing.T, exampleFolder string) (*terraform.Options, *aws.Ec2Keypair) {
	// Generate a unique ID for key
	uniqueID := random.UniqueId()

	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	// Create an EC2 KeyPair that we can use for SSH access
	keyPairName := fmt.Sprintf("tf-aws-asg-ebs-attach-%s", uniqueID)
	keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, keyPairName)

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: exampleFolder,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"aws_region": awsRegion,
			"key_name":   keyPairName,
		},
	}

	return terraformOptions, keyPair
}

func testHostDisks(t *testing.T, terraformOptions *terraform.Options, keyPair *aws.Ec2Keypair, publicIP string) {

	publicHost := ssh.Host{
		Hostname:    publicIP,
		SshKeyPair:  keyPair.KeyPair,
		SshUserName: "ec2-user",
	}

	// Keep trying
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicIP)

	// We know what to expect as an output
	var expected = LsblkOutput{
		Blockdevices: []Disk{
			Disk{Name: "xvdf1", Fstype: "xfs", Label: "XVDF", Mountpoint: "/app/xvdf"},
			Disk{Name: "xvdg1", Fstype: "xfs", Label: "", Mountpoint: "/app/xvdg"},
			Disk{Name: "xvdh", Fstype: "", Label: "", Mountpoint: ""},
		},
	}

	// Command to get info about blockdevices, it outputs json that we can then Unmarshal
	/*
		{
		  "blockdevices": [
		    {
		      "name": "xvdf1",
		      "fstype": "xfs",
		      "label": null,
		      "uuid": "ad01e85c-0ae5-4d46-9eca-1991941e6ac4",
		      "mountpoint": "/app/xvdf",
		      "children": [
		        {
		          "name": "xvdf",
		          "fstype": null,
		          "label": null,
		          "uuid": null,
		          "mountpoint": null
		        }
		      ]
		    },
		    {
		      "name": "xvdg1",
		      "fstype": "xfs",
		      "label": null,
		      "uuid": "fd658217-0b0b-4c73-a929-52e2b7410496",
		      "mountpoint": "/app/xvdg",
		      "children": [
		        {
		          "name": "xvdg",
		          "fstype": null,
		          "label": null,
		          "uuid": null,
		          "mountpoint": null
		        }
		      ]
		    },
		    {
		      "name": "xvdh",
		      "fstype": null,
		      "label": null,
		      "uuid": null,
		      "mountpoint": null
		    }
		  ]
		}
	*/

	command := "lsblk -J -fs /dev/xvdf1 /dev/xvdg1 /dev/xvdh"

	// Get output of the command from the instance
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		lsblkOutputJSON, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			return "", err
		}

		// Parse output as json
		var hostDisks LsblkOutput
		json.Unmarshal([]byte(lsblkOutputJSON), &hostDisks)

		// Compare output with waht we expect
		require.Equal(t, expected, hostDisks, "checking instance disk config failed")

		return "", nil
	})
}
