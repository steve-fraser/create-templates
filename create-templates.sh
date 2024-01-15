#!/bin/bash
CLUSTER_ID="<cluster-id>"
TOKEN="<token>"
API_ENDPOINT="https://api.cast.ai/v1/kubernetes/clusters/$CLUSTER_ID/node-templates"
DATA="@data.json"


NODE_CONFIGS=$(curl --location "https://api.cast.ai/v1/kubernetes/clusters/$CLUSTER_ID/node-configurations" --header 'Accept: application/json' --header "X-API-Key: $TOKEN")

while IFS="" read -r p || [ -n "$p" ]
do
    echo -e "\nCreate template $p"
    for i in {a,b,c,d}; do 
        NODE_CONFIG_ID=$(echo "$NODE_CONFIGS" | jq -r --arg name "az-$i" '.items[] | select(.name == $name) | .id')
        NAME=spot-$p NODE_CONFIG_ID=$NODE_CONFIG_ID NODE_CONFIG_NAME=az-$i AZ=1$i SPOT=true  DEMAND=false envsubst < "template.json" > "data.json"

        # Run curl and capture the HTTP response code
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --location "$API_ENDPOINT" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header "X-API-Key: $TOKEN" \
            --data "$DATA")

        # Check if the response code is 409 (Conflict)
        if [ "$HTTP_STATUS" -eq 409 ]; then
            echo -e "\nTemplate already exists updating..."
            curl --request PUT --location "$API_ENDPOINT/spot-$p-1$i" \
                        --header 'Content-Type: application/json' \
                        --header 'Accept: application/json' \
                        --header "X-API-Key: $TOKEN" \
                        --data "$DATA"
        else
            echo "Request successful. HTTP status: $HTTP_STATUS"
        fi

        NAME=ondemand-$p NODE_CONFIG_ID=$NODE_CONFIG_ID NODE_CONFIG_NAME=az-$i AZ=1$i SPOT=false DEMAND=true envsubst < "template.json" > "data.json"
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --location "$API_ENDPOINT" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header "X-API-Key: $TOKEN" \
            --data "$DATA")

        # Check if the response code is 409 (Conflict)
        if [ "$HTTP_STATUS" -eq 409 ]; then
             echo -e "\nTemplate already exists updating..."
            curl --request PUT --location "$API_ENDPOINT/ondemand-$p-1$i" \
                        --header 'Content-Type: application/json' \
                        --header 'Accept: application/json' \
                        --header "X-API-Key: $TOKEN" \
                        --data "$DATA"
        else
            echo "Request successful. HTTP status: $HTTP_STATUS"
        fi

    done

done <list-of-labels