output "stt_worker_function_uri" {
  value       = google_cloudfunctions2_function.stt_worker.service_config[0].uri
  description = "The URI of the stt-worker function"
}

output "llm_worker_function_uri" {
  value       = google_cloudfunctions2_function.llm_worker.service_config[0].uri
  description = "The URI of the llm-worker function"
}
