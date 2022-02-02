Include %ZUtils.Include

/// ファイル転送クライアント基底クラス
/// RESTを使用
Class %ZUtils.Client Extends %RegisteredObject
{

/// HTTPリクエスト
Property conn As %Net.HttpRequest;

/// インスタンス作成時の処理
/// インスタンス作成時にHTTP接続の準備を行う
Method %OnNew(host As %String) As %Status [ Private, ServerOnly = 1 ]
{
	set ret=$$$OK
	try {
		set ..conn = ##class(%Net.HttpRequest).%New()
		set ..conn.Server=host
		set ..conn.Port=$$$HttpPort
	} catch {
		set ret=$$$ERROR(5002,$zerror)
	}
	quit ret
}

/// データベースをダウンロードする
/// リモートのデータベースファイルの内容をローカルのIRIS.NEWにコピーする
/// dbname ... データベース名
/// dbguid ... クライアント側のDBにある^ZUtils.DatabaseGUIDの値
/// snapshot ... ダウンロードするファイルが0:データベースファイル、スナップショット
/// download ... ダウンロードされたかどうかのフラグ
Method DownloadDatabase(dbname As %String, dbguid As %String = "", snapshot As %Boolean = 0, ByRef download As %Boolean) As %Status
{

 set ret=$$$OK
 set download=0
 if dbname="" {
	 quit $$$ERROR(5001,"データベース名を指定してください")
 }
 
 try {
		 
	// データベースディレクトリの取得
	set ret=##class(Config.Configuration).GetDatabase(dbname,.dbdir)
	if $$$ISERR(ret) do $$$ErrorLogClass("データベース'"_dbname_"'のディレクトリが取得できませんでした",ret) quit

	// スナップショットの場合、デバイスが
	// 出力ストリームを設定
	set file=##class(%FileBinaryStream).%New()
	set file.Filename=dbdir_"IRIS.NEW"
	set ..conn.ReadRawMode=1
	set ..conn.ResponseStream=file

	 for retry=1:1:$$$MaxRetry { 
	 	 try {
		 	 // RESTアクセス
			 set ret=..conn.Get("/sync/db/"_dbname_"?dbguid="_dbguid_"&snapshot="_snapshot)
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode\100'=2 set ret=$$$ERROR(5001,"転送エラー Status="_..conn.HttpResponse.StatusLine) quit
			 
			 // ステータスコードが200の場合、ストリームに保存
			 if ..conn.HttpResponse.StatusCode=200 {
				 set ret=file.SaveStream()
				 set:$$$ISOK(ret) download=1
			 }
			 
		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISOK(ret)||(retry=$$$MaxRetry)
		 do $$$InfoLogClass("ダウンロードできませんでした リトライします",ret)
		 
		 hang $$$RetryInterval // リトライ間隔
	 }

 } catch err {
	set ret=err.AsStatus()
	do $$$ErrorLogClass("エラーが発生しました",ret)		
 }
 quit ret
}

/// データベースをアップロードする
/// ローカルのデータベースファイルの内容をリモートのIRIS.NEWにコピーする
Method UploadDatabase(dbname As %String) As %Status
{

 set ret=$$$OK
 if dbname="" {
	 quit $$$ERROR(5001,"データベース名を指定してください")
 }
 
 set ret=$$$OK
 try {
	// データベースディレクトリの取得
	set ret=##class(Config.Configuration).GetDatabase(dbname,.dbdir)
	if $$$ISERR(ret) do $$$ErrorLogClass("データベース'"_dbname_"'のディレクトリが取得できませんでした",ret) quit

	// 送信データを圧縮
	set ..conn.PostGzip=1
	//write "dbdir:",dbdir,!

	// データベースファイルのオープン
	set file=##class(%FileBinaryStream).%New()
	set file.Filename=dbdir_"IRIS.DAT"
	//write "size:",file.Size,!
	do file.Rewind()
	set file.ChunkSize=$$$ChunkSize
	set partnum=file.Size\$$$ChunkSize+1
	set hostname=$SYSTEM.INetInfo.LocalHostName()
	for p=1:1:partnum {
		do $$$InfoLogClass("part:"_p,"")
	 for retry=1:1:$$$MaxRetry { 
	 	 try {
		 	 // 出力パーツの設定
		 	 set file.Part=p
		 	 
		 	 // MIME typeの設定
		 	 set ..conn.ContentType="application/x-database"

		 	 // Bodyにデータを書き込む
		 	 set ..conn.EntityBody=file
			 set ret=..conn.Post("/sync/db/"_dbname_"?clientpid="_hostname_":"_$job_"&part="_p_"&last="_$select(p=partnum:1,1:0))
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode'=200 set ret=$$$ERROR(5001,"転送エラー Status="_..conn.HttpResponse.StatusLine) quit

		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISOK(ret)
		 do $$$ErrorLogClass("エラーが発生しました リトライします",ret)
		 hang $$$RetryInterval // リトライ間隔
	 }
	 quit:$$$ISERR(ret)
	}

 } catch err {
	set ret=err.AsStatus()
	do $$$ErrorLogClass("エラーが発生しました",ret)		
 }
 do:$$$ISOK(ret) $$$InfoLogClass("データベースアップロードが完了しました","")
 do:$$$ISERR(ret) $$$ErrorLogClass("データベースアップロードが失敗しました",ret)
 quit ret
}

/// 更新データをダウンロードする
/// 
/// syncset ... クライアント側のSyncSet
/// ns ... サーバ側のネームスペース
Method DownloadSyncData(syncset As %ZSYNC.SyncSet, ns As %String = "") As %Status
{
 set ret=$$$OK 
 try {
	 set:ns="" ns=^%ZUtils.Config("SYNCNS")
	 for retry=1:1:$$$MaxRetry { 
	 	 try {
		 	 // RESTアクセス
			 set ret=..conn.Get("/sync/sync/"_syncset.sId_"?clientguid="_##class(%SYS.System).InstanceGUID()_"&ns="_ns)
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode\100'=2 set ret=$$$ERROR(5001,"転送エラー Status="_..conn.HttpResponse.StatusLine) quit
			 
			 // ステータスコードが200の場合、ストリームに保存
			 if ..conn.HttpResponse.StatusCode=200 {
				 set ret=syncset.ImportStream(..conn.HttpResponse.Data)
			 }
			 
		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISOK(ret)||(retry=$$$MaxRetry)
		 do $$$InfoLogClass("ダウンロードできませんでした リトライします",ret)
		 
		 hang $$$RetryInterval // リトライ間隔
	 }

 } catch err {
	set ret=err.AsStatus()
	do $$$ErrorLogClass("エラーが発生しました",ret)		
 }
 quit ret
}

/// 更新データをアップロードする
Method UploadSyncData(syncset As %ZSYNC.SyncSet, ns As %String = "") As %Status
{

 set ret=$$$OK
 try {
	// 更新データグローバルをストリームとして送信する
	set syncdata=##class(%ZUtils.SyncDataChunkedWriter).%New()
	set syncdata.SyncSet = syncset

	 for retry=1:1:$$$MaxRetry { 
	 	 try {
		 	 // MIME typeの設定
		 	set ..conn.ContentType="application/x-iris-syncfile"
			set ..conn.EntityBody = syncdata

			 set ret=..conn.Post("/sync/sync/"_syncset.sId_"?clientguid="_##class(%SYS.System).InstanceGUID()_"&ns="_ns)
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode'=200 set ret=$$$ERROR(5001,"転送エラー Status="_..conn.HttpResponse.StatusLine) quit

			 // ステータスコードが200の場合、ストリームからIDリストを保存
			 if ..conn.HttpResponse.StatusCode=200 {
				set ret=syncset.ImportIDListStream(..conn.HttpResponse.Data)
			 }

		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISOK(ret)
		 do $$$ErrorLogClass("エラーが発生しました リトライします",ret)
		 hang $$$RetryInterval // リトライ間隔
	 }
	 quit:$$$ISERR(ret)

 } catch err {
	set ret=err.AsStatus()
	do $$$ErrorLogClass("エラーが発生しました",ret)		
 }
 do:$$$ISOK(ret) $$$InfoLogClass("データベースアップロードが完了しました","")
 do:$$$ISERR(ret) $$$ErrorLogClass("データベースアップロードが失敗しました",ret)
 quit ret
}

/// リモートジョブの実行
Method ExecJob(method As %String, args...) As %Status
{
 set ret=$$$OK
 
 try {
	 for retry=1:1:$$$MaxRetry { 
	 	 try {
		 	 // RESTアクセス
			 set key="" for {
				 set key=$order(args(key),1,val)
				 quit:key=""
				 do ..conn.InsertFormData("args",val)
		 	 }
			 set ret=..conn.Post("/sync/job/"_method)
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode'=200 do ..conn.HttpResponse.Data.OutputToDevice() set ret=$$$ERROR(5001,"通信エラー Status="_..conn.HttpResponse.StatusLine) quit

			 set response={}.%FromJSON(..conn.HttpResponse.Data)

		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISOK(ret)||(retry=$$$MaxRetry)
		 do $$$InfoLogClass("処理中にエラーが発生しました リトライします",ret)
		 
		 hang $$$RetryInterval // リトライ間隔
	 }
	 quit:$$$ISERR(ret)
	 
	 // 応答の取得
	 set ret=response.status
	 quit:$$$ISERR(ret)
	 set jobid=response.jobid
	 
	 // ジョブが終わるまで待つ
	 for wait=1:1 { 
	 	 try {
		 	 // RESTアクセス
			 set ret=..conn.Get("/sync/watchjob/"_jobid)
			 quit:$$$ISERR(ret)
			 if ..conn.HttpResponse.StatusCode'=200 do ..conn.HttpResponse.Data.OutputToDevice() set ret=$$$ERROR(5001,"通信エラー Status="_..conn.HttpResponse.StatusLine) quit

			 set response={}.%FromJSON(..conn.HttpResponse.Data)

		 } catch err { 
		 	set ret=err.AsStatus()
		 }
		 quit:$$$ISERR(ret)
		 quit:response.continue=0

		 hang $$$RetryInterval // リトライ間隔
	 }
	 quit:$$$ISERR(ret)
	 set ret=response.status

 } catch err {
	set ret=err.AsStatus()
	do $$$ErrorLogClass("エラーが発生しました",ret)		
 }
 quit ret
}

/// サーバからのJSONエラー形式から%Status形式に変換
ClassMethod GetJSONStatus(json As %DynamicAbstractObject) As %Status
{
	set err=json.errors.%Get(0)
	set it=err.params.%GetIterator()
	while it.%GetNext(.key,.value) {
		set params($I(params))=value
	}
	quit $SYSTEM.Status.Error(err.code,params...)
}

}
