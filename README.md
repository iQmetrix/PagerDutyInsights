# PagerDuty Insights

Scrapes data about resolved incidents using the PagerDuty API and sends them to New Relic Insights.
Runs on [Azure Functions](https://azure.microsoft.com/en-us/services/functions/).

# Setup instructions
[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

1. Create/gather the API keys listed below.
2. Click the button above.
3. Pick a name and location for your function app.

# Required application settings
* `PAGERDUTY_API_KEY`: Your [PagerDuty API key][pagerdutyapi] (v2).
* `INSIGHTS_INSERT_KEY`: Your [New Relic Insights insert key][insightsapi].
* `INSIGHTS_ACCOUNT`: The [numeric ID of your New Relic account][insightsaccount].

[pagerdutyapi]: https://support.pagerduty.com/hc/en-us/articles/202829310-Generating-an-API-Key
[insightsapi]: https://docs.newrelic.com/docs/insights/new-relic-insights/custom-events/insert-custom-events-insights-api#register
[insightsaccount]: https://docs.newrelic.com/docs/accounts-partnerships/accounts/account-setup/account-id

# Interesting NRQL queries

Here are some sample NRQL queries you can run or use to build dashboards:

## Who received the most alerts this week?
```sql
SELECT count(*) FROM PagerDutyIncident facet firstAssignedToName since 1 week ago timeseries auto
```
![2016_11_28_11_51_19_insights_pagerduty_activity](https://cloud.githubusercontent.com/assets/150953/20679906/71462cd0-b562-11e6-86f1-36c783f9afe0.png)

```sql
SELECT count (*) as 'Alerts received' from PagerDutyIncident since 1 week ago facet firstAssignedToName
```
![2016_11_28_11_55_22_insights_pagerduty_activity](https://cloud.githubusercontent.com/assets/150953/20679932/8fa59aee-b562-11e6-92f4-e3fb56e47bb3.png)

## What time of day are incidents occurring?
```sql
SELECT histogram(createdHour - 6, 24, 24) from PagerDutyIncident SINCE 1 week ago
```
![2016-11-28 11_56_13-insights_ pagerduty activity](https://cloud.githubusercontent.com/assets/150953/20679999/d00970ba-b562-11e6-95c9-b6c2b87da851.png)

## Are incidents resolving themselves before anyone even acknowledges them?
This could indicate false or non-actionable alerts.
```sql
SELECT count(*) as 'Incidents' from PagerDutyIncident where acknowledgedBy is null and resolvedByType NOT LIKE '%user%' since 1 week ago
```

## Have any alerts been slept through and escalated to the secondary on-call?
```sql
SELECT count(*) as 'Escalations' from PagerDutyIncident where escalations > 0 since 1 week ago
```

# Credits
This project was inspired by [a similar script authored by the New Relic team](insights-about-pagerduty). Check it out for more NRQL queries and ideas.

[insights-about-pagerduty]: https://github.com/newrelic/insights-about-pagerduty