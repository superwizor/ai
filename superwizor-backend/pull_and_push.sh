#!/bin/bash
echo "Starting Pub/Sub Pull -> Push proxy..."
while true; do
  # Check audio.uploaded
  MSG1=$(gcloud pubsub subscriptions pull audio.uploaded.debug --auto-ack --format="json" --limit=1 2>/dev/null)
  if [ "$MSG1" != "[]" ] && [ -n "$MSG1" ]; then
    echo "Received message from audio.uploaded.debug"
    DATA=$(echo "$MSG1" | jq -r '.[0].message.data')
    ATTRS=$(echo "$MSG1" | jq -c '.[0].message.attributes')
    PAYLOAD=$(jq -n --arg data "$DATA" --argjson attrs "$ATTRS" '{message: {data: $data, attributes: $attrs}}')
    echo "Pushing to localhost:8083/worker/stt..."
    curl -s -X POST http://localhost:8083/worker/stt -H "Content-Type: application/json" -d "$PAYLOAD"
    echo ""
  fi

  # Check transcript.completed
  MSG2=$(gcloud pubsub subscriptions pull transcript.completed.debug --auto-ack --format="json" --limit=1 2>/dev/null)
  if [ "$MSG2" != "[]" ] && [ -n "$MSG2" ]; then
    echo "Received message from transcript.completed.debug"
    DATA=$(echo "$MSG2" | jq -r '.[0].message.data')
    ATTRS=$(echo "$MSG2" | jq -c '.[0].message.attributes')
    PAYLOAD=$(jq -n --arg data "$DATA" --argjson attrs "$ATTRS" '{message: {data: $data, attributes: $attrs}}')
    echo "Pushing to localhost:8083/worker/llm..."
    curl -s -X POST http://localhost:8083/worker/llm -H "Content-Type: application/json" -d "$PAYLOAD"
    echo ""
  fi

  sleep 2
done
