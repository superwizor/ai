variable "project_id" {
  type = string
}

resource "google_pubsub_topic" "audio_uploaded" {
  name    = "audio.uploaded"
  project = var.project_id
}

resource "google_pubsub_topic" "transcript_completed" {
  name    = "transcript.completed"
  project = var.project_id
}

output "topic_audio_uploaded" {
  value = google_pubsub_topic.audio_uploaded.id
}

output "topic_transcript_completed" {
  value = google_pubsub_topic.transcript_completed.id
}
