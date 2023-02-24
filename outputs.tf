output "service_ip" {
  value = aws_cloudfront_distribution.this.domain_name
}
