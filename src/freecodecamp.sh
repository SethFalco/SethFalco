#!/bin/bash

# Grabs the total number of visitors that can be attributed to the specified
# author's published articles.

set -euo pipefail

# On 2023-07-01, Google stopped Universal Analytics (UA) from collecting data,
# pushing all users to migrate to Google Analytics 4 (GA4). Data was not
# portable between the two versions, and it's no longer possible to query the
# old data as it became inaccessible on 2024-07-01.
#
# In 4ce8c20ecd538501928af76fec0a26f171590545 (2023-09-02) I manually updated
# the stats by adding the UA and GA4 data myself.
#
# As the UA data no longer exists, we'll query for all data after 2023-09-03,
# the day after my last manual recording, and just trust that I hardcoded an
# accurate enough figure before that date.
EXISTING_VISITORS=150000

# To keep the page looking pretty, we'll always round down to a clean number.
PAGE_VIEW_BRACKET=25000

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
HASHNODE_QUERY=$(sed "s/HASHNODE_PUBLISHER_ID/$HASHNODE_PUBLISHER_ID/" "$SCRIPT_DIR/requests/hashnode.gql")
HASHNODE_REQUEST=$(jq -Rs '{ query: . }' <<< "$HASHNODE_QUERY")
HASHNODE_RESPONSE=$(
  curl --fail -sS \
    -X POST \
    -d "$HASHNODE_REQUEST" \
    -H "Content-Type: application/json" \
    'https://gql.hashnode.com'
  )
ARTICLE_SLUGS=$(
  jq '.data.searchPostsOfPublication.edges[].node.slug' <<< "$HASHNODE_RESPONSE"
)
GA_FILTERS=$(
  jq '[.,inputs] | map({
    filter: {
      fieldName: "pagePath",
      stringFilter: {
        matchType: "BEGINS_WITH",
        value: "/news/\(.)",
        caseSensitive: true
      }
    }
  })' <<< "$ARTICLE_SLUGS"
)
GA_REQUEST=$(
  jq \
    --argjson filters "$GA_FILTERS" \
    '.dimensionFilter.orGroup.expressions = $filters' < "$SCRIPT_DIR/requests/analytics-report.json"
)
GA_AUTH=$(
  curl --fail -sS \
    -X POST \
    --data "client_id=$GOOGLE_CLIENT_ID&client_secret=$GOOGLE_CLIENT_SECRET&refresh_token=$GOOGLE_OAUTH_TOKEN&grant_type=refresh_token" \
    'https://accounts.google.com/o/oauth2/token'
)
GA_ACCESS_TOKEN=$(jq -r '.access_token' <<< "$GA_AUTH")
GA_RESPONSE=$(
  curl --fail -sS \
    -X POST \
    -d "$GA_REQUEST" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $GA_ACCESS_TOKEN" \
    "https://analyticsdata.googleapis.com/v1beta/properties/$GA_PROPERTY_ID:runReport"
)
GA4_VISITORS=$(jq -r '.rows[].metricValues[].value' <<< "$GA_RESPONSE")
TOTAL_VISITORS=$(( (GA4_VISITORS + EXISTING_VISITORS) / PAGE_VIEW_BRACKET * PAGE_VIEW_BRACKET ))
VISITORS=$(printf "%'d+" $TOTAL_VISITORS)

printf '<!-- Do not edit—changes will be overridden! Please see the src/ directory. -->\n\n'
sed "s/VISITORS/$VISITORS/" "$SCRIPT_DIR/TEMPLATE.md"
