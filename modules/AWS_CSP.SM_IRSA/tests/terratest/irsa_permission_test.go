package test

import (
	//"encoding/json"
	"fmt"
	//"github.com/aws/aws-sdk-go/aws"
	//"github.com/aws/aws-sdk-go/aws/session"
	//"github.com/aws/aws-sdk-go/service/iam"
	terraaws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"os"
	"testing"
)

// An example of how to test the simple Terraform module in examples/terraform-basic-example using Terratest.
func TestIrsaPermission(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	env := "testing"
	aws_region := "ap-east-1"
	aws_account_id := terraaws.GetAccountId(t)
	//aws_partition  := "aws"
	role_name := fmt.Sprintf("iam-role-%s-test", uniqueId)
	role_description := "irsa test "
	dummyOidcId := "19E9B0820E7FEC8E964F2AC2A5876311"
	provider_arn := fmt.Sprintf("arn:aws:iam::%s:oidc-provider/oidc.eks.%s.amazonaws.com/id/%s",aws_account_id,aws_region,dummyOidcId )
	dummynssa := []string{"test:test"}
	//cluster_name := "unittest-aws-a"
	//cluster_role_arn := "arn:aws:iam::112106310596:role/iam-role-infra-eks-cluster"
	//cluster_control_plane_subnet_names := []string{"shared-services-1a", "shared-services-1b", "shared-services-1c"}
	//cluster_version := "1.24"

	rootTestDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get root test directory.")
	}

	testDir, err := files.CopyTerraformFolderToTemp("../../", fmt.Sprintf("TestIrsaPermission-%s-", uniqueId))
	if err != nil {
		t.Fatalf("Failed to copy terraform folder to test directory.")
	}
	defer func(path string) {
		err := os.RemoveAll(path)
		if err != nil {
			t.Fatalf("Failed to remove test directory.")
		}
	}(testDir)
	logger.Log(t, fmt.Sprintf("testDir: %s", testDir))
	err = files.CopyFile(fmt.Sprintf("%s/providers.tf", rootTestDir), fmt.Sprintf("%s/providers.tf", testDir))
	if err != nil {
		t.Fatalf("Failed to copy prociders.tf to test directory.")
	}
	/*err = files.CopyFile(fmt.Sprintf("../../terraform.tfstate"), fmt.Sprintf("%s/terraform.tfstate", testDir))
	if err != nil {
		t.Fatalf("Failed to copy terraform.tfstate to test directory.")
	}*/

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// website::tag::1::Set the path to the Terraform code that will be tested.
		// The path to where our Terraform code is located
		TerraformDir: testDir,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"common_tags": map[string]interface{}{
				"hosting-account": aws_account_id,
				"app-environment": env,
			},
			//"aws_region" : aws_region,
			//"aws_account_id" : aws_account_id,
			"role_name" :role_name,
			"role_description" : role_description,
			//"provider_arn" :provider_arn,
			//"s3_bucket_name": s3BucketName,
			"oidc_providers": map[string]interface{}{
				"this": map[string]interface{}{
					"provider_arn":  provider_arn,
					"namespace_service_accounts": dummynssa,
				},
			},
		},

		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{fmt.Sprintf("%s/irsa_permission_test.tfvars", rootTestDir)},
		// Disable colors in Terraform commands so its easier to parse stdout/stderr
		NoColor: true,
	})

	// website::tag::4::Clean up resources with "terraform destroy". Using "defer" runs the command at the end of the test, whether the test succeeds or fails.
	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// website::tag::2::Run "terraform init" and "terraform apply".
	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)
	/*
	// Run `terraform output` to get the values of output variables
	actualRoleArn := terraform.Output(t, terraformOptions, "fluent_irsa_role_arn")
	actualRolePermissionJson := terraform.Output(t, terraformOptions, "aws_iam_policy_fluent")

	// Create a IAM service client.
	sess, _ := session.NewSession(&aws.Config{
		Region: aws.String(aws_region)},
	)
	svc := iam.New(sess)

	// Verify the role allow to operate following action with correct s3 bucket name
	t1ActionNames := []string{"s3:PutObject"}
	var t1ActionNamePtrs []*string
	for _, actionName := range t1ActionNames {
		t1ActionNamePtrs = append(t1ActionNamePtrs, &actionName)
	}
	
	t1ResourceArns := []string{
		fmt.Sprintf("arn:aws:s3:::s3-%s-metric",cluster_name),
		fmt.Sprintf("arn:aws:s3:::s3-%s-container-log",cluster_name),
		fmt.Sprintf("arn:aws:s3:::s3-%s-audit-log",cluster_name),
		fmt.Sprintf("arn:aws:s3:::s3-%s-alert",cluster_name),
	}

	var t1ResourceArnPtrs []*string
	for _, t1ResourceArn := range t1ResourceArns {
		t1ResourceArnPtrs = append(t1ResourceArnPtrs, &t1ResourceArn)
	}

	t1Response, t1Err := svc.SimulateCustomPolicy(&iam.SimulateCustomPolicyInput{
		ActionNames:     t1ActionNamePtrs,
		CallerArn:       &actualRoleArn,
		PolicyInputList: []*string{&actualRolePermissionJson},
		ResourceArns:    t1ResourceArnPtrs,
	})
	if t1Err != nil {
		t.Errorf("Test Case 1 failed. Exception(%s)", t1Err.Error())
	}
	for _, evaluationResult := range t1Response.EvaluationResults {
		if *evaluationResult.EvalDecision != "allowed" {
			evalDecisionDetails, err := json.Marshal(evaluationResult.EvalDecisionDetails)
			if err != nil {
				t.Errorf("Test Case 1 failed. Exception(%s)", err.Error())
			}
			t.Errorf("Test Case 1 failed. EvalActionName(%s); EvalDecision(%s); EvalDecisionDetails(%s); EvalResourceName:(%s)",
				*evaluationResult.EvalActionName, *evaluationResult.EvalDecision, string(evalDecisionDetails), *evaluationResult.EvalResourceName)
		}
	}

	// Verify the role allow to operate following action with wrong s3 bucket name
	t2ActionNames := []string{"s3:PutObject"}
	var t2ActionNamePtrs []*string
	for _, t2ActionName := range t2ActionNames {
		t2ActionNamePtrs = append(t2ActionNamePtrs, &t2ActionName)
	}
	t2ResourceArns := []string{fmt.Sprintf("arn:aws:s3:::wrong-%s", aws_account_id)}
	var t2ResourceArnPtrs []*string
	for _, t2ResourceArn := range t2ResourceArns {
		t2ResourceArnPtrs = append(t2ResourceArnPtrs, &t2ResourceArn)
	}
	t2Response, t2Err := svc.SimulateCustomPolicy(&iam.SimulateCustomPolicyInput{
		ActionNames:     t2ActionNamePtrs,
		CallerArn:       &actualRoleArn,
		PolicyInputList: []*string{&actualRolePermissionJson},
		ResourceArns:    t2ResourceArnPtrs,
	})
	if t2Err != nil {
		t.Errorf("Test Case 2 failed. Exception(%s)", t2Err.Error())
	}
	for _, evaluationResult := range t2Response.EvaluationResults {
		if *evaluationResult.EvalDecision != "implicitDeny" {
			evalDecisionDetails, err := json.Marshal(evaluationResult.EvalDecisionDetails)
			if err != nil {
				t.Errorf("Test Case 2 failed. Exception(%s)", err.Error())
			}
			t.Errorf("Test Case 2 failed. EvalActionName(%s); EvalDecision(%s); EvalDecisionDetails(%s); EvalResourceName:(%s)",
				*evaluationResult.EvalActionName, *evaluationResult.EvalDecision, string(evalDecisionDetails), *evaluationResult.EvalResourceName)
		}
		
	}
	*/
}
