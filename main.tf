/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  enable_eventarc  = length(var.workflow_trigger.event_arc == null ? {} : var.workflow_trigger.event_arc) > 0 ? 1 : 0
  enable_scheduler = length(var.workflow_trigger.cloud_scheduler == null ? {} : var.workflow_trigger.cloud_scheduler) > 0 ? 1 : 0
}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}

resource "google_eventarc_trigger" "workflow" {
  count           = local.enable_eventarc
  project         = var.project_id
  name            = "name"
  location        = var.region
  service_account = data.google_compute_default_service_account.default.email
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    workflow = google_workflows_workflow.workflow.id
  }
}

resource "google_cloud_scheduler_job" "workflow" {
  count            = local.enable_scheduler
  project          = var.project_id
  name             = var.workflow_trigger.cloud_scheduler.name
  description      = "Cloud Scheduler for Workflow Jpb"
  schedule         = var.workflow_trigger.cloud_scheduler.cron
  time_zone        = var.workflow_trigger.cloud_scheduler.time_zone
  attempt_deadline = var.workflow_trigger.cloud_scheduler.deadline
  region           = var.region

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.workflow.id}/executions"
    body        = base64encode("{\"argument\":\"{}\",\"callLogLevel\":\"CALL_LOG_LEVEL_UNSPECIFIED\"}")

    oauth_token {
      service_account_email = data.google_compute_default_service_account.default.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

}

resource "google_workflows_workflow" "workflow" {
  name            = var.workflow_name
  region          = var.region
  description     = var.workflow_description
  service_account = var.service_account_email
  project         = var.project_id
  labels          = var.workflow_labels
  source_contents = var.workflow_source
}
