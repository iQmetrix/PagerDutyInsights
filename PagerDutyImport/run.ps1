$lastTime = [DateTimeOffset]::UtcNow.AddMinutes(-5)

# PagerDuty API reference:
# https://v2.developer.pagerduty.com/v2/page/api-reference
$baseUri = "https://api.pagerduty.com"
$headers = @{
    Accept = 'application/vnd.pagerduty+json;version=2'
    Authorization = "Token token=$($env:APPSETTING_PAGERDUTY_API_KEY)"
}

# Find incidents that have been resolved in the last time period
$query = @{
    offset = 0
    limit = 100
    'until' = [DateTimeOffset]::UtcNow.ToString('o')
    since = $lastTime.ToString('o')
}
$resolveLogs = Invoke-RestMethod -Uri "$baseUri/log_entries" -Headers $headers -Method Get -Body $query -Verbose |
    Select-Object -ExpandProperty log_entries |
    Where-Object { $_.type -match 'resolve_log_entry' }

Write-Output "Found $($resolveLogs.Count) resolved incidents since last run"
if ($resolveLogs) {
    $insightsEvents = @()
    $resolveLogs | ForEach-Object {
        # Fetch details about this incident
        $incident = Invoke-RestMethod -Uri $_.incident.self -Headers $headers -Verbose | select -ExpandProperty incident

        # Fetch the rest of the logs for this incident
        $logs = Invoke-RestMethod -Uri "$baseUri/incidents/$($incident.id)/log_entries" -Headers $headers -Verbose | select -ExpandProperty log_entries

        # Find interesting things in the logs
        $escalationCount = $logs | ? { $_.type -match 'escalate_log_entry' } | measure | select -ExpandProperty count
        $firstAssignment = $logs | ? { $_.type -match 'assign_log_entry' } | sort created_at | select -First 1
        $firstAck = $logs | ? { $_.type -match 'acknowledge_log_entry' } | sort created_at | select -First 1
        $trigger = $logs | ? { $_.type -match 'trigger_log_entry' }

        $opened = ([DateTimeOffset]$incident.created_at).ToUnixTimeSeconds()
        $createdHour = ([DateTimeOffset]$incident.created_at).Hour
        $resolved = ([DateTimeOffset]$_.created_at).ToUnixTimeSeconds()
        if ($null -ne $firstAck)
        {
            $acknowledgedAt = ([DateTimeOffset]$firstAck.created_at).ToUnixTimeSeconds()
        }
        $openDurationSeconds = $resolved - $opened

        # Put together an insights event
        $insightsEvents += @{
            # Bump this number if you modify the schema, so that the Insights queries can use the value
            eventVersion = 3
            timestamp = $opened
            eventType = 'PagerDutyIncident'

            incidentId = $incident.id
            incidentNumber = $incident.incident_number
            incidentUrl = $incident.html_url
            incidentKey = $incident.incident_key
            serviceId = $incident.service.id
            serviceName = $incident.service.summary
            teamId = $incident.teams.id
            teamName = $incident.teams.summary
            urgency = $incident.urgency

            escalationPolicyId = $incident.escalation_policy.id
            escalationPolicyName = $incident.escalation_policy.summary
            escalationCount = $escalationCount

            triggerType = $trigger.summary
            triggerName = $trigger.agent.summary

            acknowledgedAt = $acknowledgedAt

            resolvedById = $_.agent.id
            resolvedByName = $_.agent.summary
            resolvedByType = $_.agent.type
            resolvedAt = $resolved
            openDurationSeconds = $openDurationSeconds
            createdHour = $createdHour

            # The incident may be assigned to multiple users at once, if so just glue them together
            firstAssignedToName = [string]$firstAssignment.assignees.summary
            firstAssignedToId = [string]$firstAssignment.assignees.id
        }
    }
}

if ($insightsEvents)
{
    Write-Output "Submitting events to Insights"
    $insightsInvokeRestMethodArgs = @{
        ContentType = 'application/json'
        Headers = @{ "X-Insert-Key" = $env:APPSETTING_INSIGHTS_INSERT_KEY }
        Uri = "https://insights-collector.newrelic.com/v1/accounts/$($env:APPSETTING_INSIGHTS_ACCOUNT)/events"
        Method = 'Post'
        Body = $insightsEvents | ConvertTo-Json
    }
    Invoke-RestMethod -Verbose @insightsInvokeRestMethodArgs
}