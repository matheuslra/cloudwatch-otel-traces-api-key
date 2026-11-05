#!/usr/bin/env python3
"""Send one small trace over OTLP/HTTP, either through the collector or straight to CloudWatch.

Through the collector (no key here, the collector holds it):
    OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces python app/send_spans.py

Straight to the endpoint (the app holds the key):
    OTLP_TRACES_ENDPOINT=https://xray.us-east-1.amazonaws.com/v1/traces \
    XRAY_API_KEY=... python app/send_spans.py
"""
import os

from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

endpoint = os.environ["OTLP_TRACES_ENDPOINT"]
api_key = os.environ.get("XRAY_API_KEY")
headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}

provider = TracerProvider(resource=Resource.create({"service.name": "api-key-demo"}))
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, headers=headers)))
tracer = provider.get_tracer("api-key-demo")

with tracer.start_as_current_span("checkout"):
    with tracer.start_as_current_span("charge-card") as span:
        span.set_attribute("demo.outside_aws", True)

provider.shutdown()
print(f"Finished sending 2 spans to {endpoint}. The exporter logs any failure above, such as a 403 for a bad key.")
