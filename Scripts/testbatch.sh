#!/bin/bash

# Azure OpenAI Batch Testing Script via APIM
# This script tests Azure OpenAI batch operations through an APIM instance
# Requires an APIM subscription key to be configured

# ============================================================================
# CONFIGURATION - UPDATE THESE VARIABLES FOR YOUR ENVIRONMENT
# ============================================================================

# APIM endpoint configuration
APIM_GATEWAY_URL="https://your-apim-instance.azure-api.net"
API_NAME="your-api-name"
APIM_SUBSCRIPTION_KEY="your-apim-subscription-key"

# Azure OpenAI configuration
DEPLOYMENT_NAME="your-deployment-name"
API_VERSION="2024-12-01-preview"

# ============================================================================
# SCRIPT VARIABLES
# ============================================================================

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BATCH_FILE="batch_input_${TIMESTAMP}.jsonl"
RESULTS_FILE="batch_results_${TIMESTAMP}.jsonl"
FILE_ID=""
BATCH_ID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it (e.g., 'brew install jq' or 'apt-get install jq')"
        exit 1
    fi
    print_success "jq is installed"
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi
    print_success "curl is installed"
    
    # Validate APIM subscription key is provided
    if [ -z "$APIM_SUBSCRIPTION_KEY" ] || [ "$APIM_SUBSCRIPTION_KEY" == "your-apim-subscription-key" ]; then
        print_error "APIM_SUBSCRIPTION_KEY is not configured. Please set it in the script."
        exit 1
    fi
    print_success "APIM subscription key is configured"
}

create_batch_file() {
    print_header "Creating Batch Input File"
    
    cat > "$BATCH_FILE" << 'EOF'
{"custom_id": "request-1", "method": "POST", "url": "/chat/completions", "body": {"model": "o4-mini", "messages": [{"role": "user", "content": "What is the capital of France?"}], "max_completion_tokens": 100}}
{"custom_id": "request-2", "method": "POST", "url": "/chat/completions", "body": {"model": "o4-mini", "messages": [{"role": "user", "content": "Explain quantum computing in simple terms."}], "max_completion_tokens": 100}}
{"custom_id": "request-3", "method": "POST", "url": "/chat/completions", "body": {"model": "o4-mini", "messages": [{"role": "user", "content": "Write a haiku about programming."}], "max_completion_tokens": 100}}
EOF
    
    if [ -f "$BATCH_FILE" ]; then
        print_success "Created batch file: $BATCH_FILE"
        print_info "File contains $(wc -l < "$BATCH_FILE") requests"
    else
        print_error "Failed to create batch file"
        exit 1
    fi
}

upload_batch_file() {
    print_header "Uploading Batch File to Azure OpenAI"
    
    local upload_url="${APIM_GATEWAY_URL}/${API_NAME}/openai/files?api-version=${API_VERSION}"
    
    print_info "Uploading to: $upload_url"
    
    # Create a temporary file for the response
    local response_file=$(mktemp)
    
    # Upload the file using curl
    local http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
        -X POST "$upload_url" \
        -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "purpose=batch" \
        -F "file=@${BATCH_FILE};type=application/json")
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        FILE_ID=$(jq -r '.id' "$response_file")
        print_success "File uploaded successfully"
        print_success "File ID: $FILE_ID"
    else
        print_error "File upload failed with HTTP $http_code"
        echo "Response:"
        cat "$response_file"
        rm "$response_file"
        exit 1
    fi
    
    rm "$response_file"
}

create_batch_job() {
    print_header "Creating Batch Job"
    
    local batch_url="${APIM_GATEWAY_URL}/${API_NAME}/openai/batches?api-version=${API_VERSION}"
    
    print_info "Creating batch at: $batch_url"
    
    # Create the batch request body
    local batch_body=$(jq -n \
        --arg input_file_id "$FILE_ID" \
        --arg endpoint "/chat/completions" \
        '{
            input_file_id: $input_file_id,
            endpoint: $endpoint,
            completion_window: "24h"
        }')
    
    # Create a temporary file for the response
    local response_file=$(mktemp)
    
    # Create the batch job
    local http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
        -X POST "$batch_url" \
        -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
        -H "Content-Type: application/json" \
        -d "$batch_body")
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        BATCH_ID=$(jq -r '.id' "$response_file")
        local status=$(jq -r '.status' "$response_file")
        print_success "Batch job created successfully"
        print_success "Batch ID: $BATCH_ID"
        print_info "Initial Status: $status"
    else
        print_error "Batch job creation failed with HTTP $http_code"
        echo "Response:"
        cat "$response_file"
        rm "$response_file"
        exit 1
    fi
    
    rm "$response_file"
}

monitor_batch_status() {
    print_header "Monitoring Batch Job Status"
    
    local status_url="${APIM_GATEWAY_URL}/${API_NAME}/openai/batches/${BATCH_ID}?api-version=${API_VERSION}"
    local status="validating"
    local poll_count=0
    local max_polls=60  # Max 5 minutes (60 * 5 seconds)
    
    print_info "Checking status every 5 seconds..."
    
    while [ "$status" != "completed" ] && [ "$status" != "failed" ] && [ "$status" != "cancelled" ]; do
        sleep 5
        poll_count=$((poll_count + 1))
        
        # Create a temporary file for the response
        local response_file=$(mktemp)
        
        local http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
            -X GET "$status_url" \
            -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY")
        
        if [ "$http_code" -eq 200 ]; then
            status=$(jq -r '.status' "$response_file")
            local request_counts=$(jq -r '.request_counts | "Total: \(.total), Completed: \(.completed), Failed: \(.failed)"' "$response_file")
            
            echo -e "${BLUE}[Poll #$poll_count] Status: $status | $request_counts${NC}"
        else
            print_warning "Failed to get status (HTTP $http_code)"
            cat "$response_file"
        fi
        
        rm "$response_file"
        
        if [ $poll_count -ge $max_polls ]; then
            print_warning "Max polling attempts reached. Batch may still be processing."
            break
        fi
    done
    
    if [ "$status" == "completed" ]; then
        print_success "Batch job completed successfully!"
    elif [ "$status" == "failed" ]; then
        print_error "Batch job failed"
        exit 1
    elif [ "$status" == "cancelled" ]; then
        print_error "Batch job was cancelled"
        exit 1
    fi
}

retrieve_results() {
    print_header "Retrieving Batch Results"
    
    # First get the batch details to find the output file ID
    local batch_url="${APIM_GATEWAY_URL}/${API_NAME}/openai/batches/${BATCH_ID}?api-version=${API_VERSION}"
    local response_file=$(mktemp)
    
    curl -s -o "$response_file" \
        -X GET "$batch_url" \
        -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY"
    
    local output_file_id=$(jq -r '.output_file_id' "$response_file")
    rm "$response_file"
    
    if [ -z "$output_file_id" ] || [ "$output_file_id" == "null" ]; then
        print_error "No output file ID found"
        exit 1
    fi
    
    print_info "Output File ID: $output_file_id"
    
    # Download the results file
    local results_url="${APIM_GATEWAY_URL}/${API_NAME}/openai/files/${output_file_id}/content?api-version=${API_VERSION}"
    
    curl -s -o "$RESULTS_FILE" \
        -X GET "$results_url" \
        -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY"
    
    if [ -f "$RESULTS_FILE" ]; then
        print_success "Results downloaded to: $RESULTS_FILE"
        print_info "Number of results: $(wc -l < "$RESULTS_FILE")"
    else
        print_error "Failed to download results"
        exit 1
    fi
}

display_results() {
    print_header "Displaying Results"
    
    if [ ! -f "$RESULTS_FILE" ]; then
        print_error "Results file not found"
        return
    fi
    
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        echo -e "\n${GREEN}--- Result #$line_num ---${NC}"
        
        # Parse the JSON line
        local custom_id=$(echo "$line" | jq -r '.custom_id')
        local status=$(echo "$line" | jq -r '.response.status_code')
        
        echo "Custom ID: $custom_id"
        echo "Status Code: $status"
        
        if [ "$status" == "200" ]; then
            # For o4-mini (reasoning model), content might be null
            local content=$(echo "$line" | jq -r '.response.body.choices[0].message.content')
            local reasoning_tokens=$(echo "$line" | jq -r '.response.body.usage.completion_tokens_details.reasoning_tokens // 0')
            
            if [ "$content" != "null" ] && [ -n "$content" ]; then
                echo -e "${BLUE}Response:${NC} $content"
            else
                echo -e "${YELLOW}Response: (null content - reasoning model)${NC}"
            fi
            
            if [ "$reasoning_tokens" != "0" ]; then
                echo -e "${BLUE}Reasoning Tokens:${NC} $reasoning_tokens"
            fi
            
            # Show token usage
            local prompt_tokens=$(echo "$line" | jq -r '.response.body.usage.prompt_tokens')
            local completion_tokens=$(echo "$line" | jq -r '.response.body.usage.completion_tokens')
            local total_tokens=$(echo "$line" | jq -r '.response.body.usage.total_tokens')
            echo -e "${BLUE}Tokens:${NC} Prompt=$prompt_tokens, Completion=$completion_tokens, Total=$total_tokens"
        else
            local error=$(echo "$line" | jq -r '.response.body.error // "Unknown error"')
            echo -e "${RED}Error:${NC} $error"
        fi
    done < "$RESULTS_FILE"
}

cleanup() {
    print_header "Cleanup"
    
    if [ -f "$BATCH_FILE" ]; then
        print_info "Batch input file saved: $BATCH_FILE"
    fi
    
    if [ -f "$RESULTS_FILE" ]; then
        print_info "Results file saved: $RESULTS_FILE"
    fi
    
    print_success "Script completed successfully!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Azure OpenAI Batch Testing via APIM"
    
    echo "Configuration:"
    echo "  APIM Gateway: $APIM_GATEWAY_URL"
    echo "  API Name: $API_NAME"
    echo "  Deployment: $DEPLOYMENT_NAME"
    echo "  API Version: $API_VERSION"
    echo ""
    
    # Execute the workflow
    check_prerequisites
    create_batch_file
    upload_batch_file
    create_batch_job
    monitor_batch_status
    retrieve_results
    display_results
    cleanup
}

# Run the main function
main
