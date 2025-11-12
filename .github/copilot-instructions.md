# Terraform Azure APIM with OpenAI Backend

This repository contains Terraform configurations for deploying Azure API Management (APIM) with Azure OpenAI backend services, including comprehensive LLM logging and diagnostics capabilities.

## Project Structure

The Terraform configuration is organized into modules:
- **networking**: VNet, subnets, NSGs, private DNS zones
- **openai**: Azure OpenAI service with private endpoints
- **apim**: API Management with OpenAI backend configuration
- **monitoring**: Application Insights, Log Analytics, Event Hub
- **diagnostics**: LLM logging configuration using azapi provider

## Features

- Private Azure OpenAI deployment with GPT and embedding models
- API Management with custom policies for OpenAI integration
- Comprehensive logging and monitoring setup
- Token usage tracking and chargeback capabilities
- Private endpoints and network isolation
- Azure API diagnostics for LLM request/response logging

## Development Guidelines

- Use Terraform modules for component organization
- Follow Azure naming conventions and tagging standards
- Implement proper security with managed identities and private endpoints
- Include comprehensive variable validation and documentation