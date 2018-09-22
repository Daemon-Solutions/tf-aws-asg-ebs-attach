data "local_file" "ssm_document" {
  count    = "${var.enable_ssm}"
  filename = "${var.ssm_document_path != "" ? "${var.ssm_document_path}" : "${path.module}/include/ssm_document.yaml"}"
}

resource "aws_ssm_document" "ssm" {
  count           = "${var.enable_ssm}"
  name            = "${var.ssm_document_name}"
  document_type   = "Command"
  document_format = "${var.ssm_document_format}"
  content         = "${data.local_file.ssm_document.content}"
}
