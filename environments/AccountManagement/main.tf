########################################################
## 費用レポートのエクスポート先の設定
########################################################

module "cur_destination" {
  source = "../../modules/BillingDataExtract"
  destination_bucket_name = var.destination_bucket_name
  source_account_list = var.source_account_list
  schedule = var.schedule
}

########################################################
## 費用レポートのエクスポート
########################################################

module "cur_source" {
  source = "../../modules/BillingDataExport"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  destination_bucket_name = var.destination_bucket_name
  destination_account_id = var.destination_account_id
}