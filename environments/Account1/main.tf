########################################################
## 費用レポートのエクスポート
########################################################

module "cur_source" {
  source = "../../modules/BillingDataExport"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  destination_bucket_name = var.destination_bucket_name # 費用レポートを保存するS3バケット名を設定
  destination_account_id = var.destination_account_id # 費用レポートを保存するAWSアカウントIDを設定
}