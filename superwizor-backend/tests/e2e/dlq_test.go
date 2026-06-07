//go:build e2e
// +build e2e

package e2e_test

import (
	"encoding/json"
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type pubsubSubscription struct {
	DeadLetterPolicy struct {
		DeadLetterTopic     string `json:"deadLetterTopic"`
		MaxDeliveryAttempts int    `json:"maxDeliveryAttempts"`
	} `json:"deadLetterPolicy"`
}

func TestDLQ_Configuration(t *testing.T) {
	project := os.Getenv("GCP_PROJECT_ID")
	if project == "" {
		project = "superwizor-ai-25ecd"
	}
	region := os.Getenv("GCP_REGION")
	if region == "" {
		region = "europe-central2"
	}

	// Verify gcloud CLI is available
	_, err := exec.LookPath("gcloud")
	if err != nil {
		t.Skip("Skipping DLQ configuration test: gcloud CLI not found on PATH")
	}

	// Verify we can access the GCP project
	testCmd := exec.Command("gcloud", "config", "get-value", "project")
	if err := testCmd.Run(); err != nil {
		t.Skip("Skipping DLQ configuration test: gcloud is not authenticated or project inaccessible")
	}

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E DLQ Configuration Verification Test")
	t.Logf("  Project: %s  Region: %s", project, region)
	t.Logf("══════════════════════════════════════════════════════════════")

	triggers := []struct {
		functionName string
		expectedDLQ  string
		expectedMax  int
	}{
		{
			functionName: "stt-worker",
			expectedDLQ:  "audio.uploaded.dlq",
			expectedMax:  100,
		},
		{
			functionName: "llm-worker",
			expectedDLQ:  "transcript.completed.dlq",
			expectedMax:  100,
		},
		{
			functionName: "notification-worker-on-deleted",
			expectedDLQ:  "session.deleted.dlq",
			expectedMax:  100,
		},
		{
			functionName: "notification-worker-on-status",
			expectedDLQ:  "session.status_changed.dlq",
			expectedMax:  100,
		},
	}

	for _, tc := range triggers {
		tc := tc
		t.Run(tc.functionName, func(t *testing.T) {
			t.Logf("Checking Eventarc trigger for %s ...", tc.functionName)

			// Step 1: Get trigger path from function description
			args := []string{
				"functions", "describe", tc.functionName,
				"--gen2",
				"--region=" + region,
				"--project=" + project,
				"--format=value(eventTrigger.trigger)",
			}
			triggerPathBytes, err := exec.Command("gcloud", args...).Output()
			if err != nil {
				t.Skipf("Cloud Function %s not deployed on staging (no eventTrigger)", tc.functionName)
				return
			}
			triggerPath := strings.TrimSpace(string(triggerPathBytes))
			if triggerPath == "" {
				t.Skipf("Cloud Function %s trigger path is empty", tc.functionName)
				return
			}

			// Extract trigger name (last part of resource path)
			parts := strings.Split(triggerPath, "/")
			triggerName := parts[len(parts)-1]

			// Step 2: Get transport subscription from Eventarc trigger description
			args = []string{
				"eventarc", "triggers", "describe", triggerName,
				"--location=" + region,
				"--project=" + project,
				"--format=value(transport.pubsub.subscription)",
			}
			subPathBytes, err := exec.Command("gcloud", args...).Output()
			require.NoError(t, err, "describe eventarc trigger %s", triggerName)
			subPath := strings.TrimSpace(string(subPathBytes))
			require.NotEmpty(t, subPath, "Eventarc trigger %s must have transport subscription", triggerName)

			// Extract subscription name
			subParts := strings.Split(subPath, "/")
			subName := subParts[len(subParts)-1]

			// Step 3: Describe Pub/Sub subscription in JSON format
			args = []string{
				"pubsub", "subscriptions", "describe", subName,
				"--project=" + project,
				"--format=json",
			}
			subJSONBytes, err := exec.Command("gcloud", args...).Output()
			require.NoError(t, err, "describe pubsub subscription %s", subName)

			var sub pubsubSubscription
			err = json.Unmarshal(subJSONBytes, &sub)
			require.NoError(t, err, "parse pubsub subscription json")

			// Step 4: Assert DLQ settings
			t.Logf("✓ Found subscription: %s", subName)
			t.Logf("  DLQ Topic: %s (Expected containing: %s)", sub.DeadLetterPolicy.DeadLetterTopic, tc.expectedDLQ)
			t.Logf("  Max Delivery Attempts: %d (Expected: %d)", sub.DeadLetterPolicy.MaxDeliveryAttempts, tc.expectedMax)

			assert.Contains(t, sub.DeadLetterPolicy.DeadLetterTopic, tc.expectedDLQ,
				"subscription %s must dead-letter to %s", subName, tc.expectedDLQ)
			assert.Equal(t, tc.expectedMax, sub.DeadLetterPolicy.MaxDeliveryAttempts,
				"subscription %s must have max delivery attempts set to %d", subName, tc.expectedMax)
		})
	}
}
