const { VertexAI } = require('@google-cloud/vertexai');
const { Storage } = require('@google-cloud/storage');
const { Octokit } = require("@octokit/rest");

exports.main = async (event, context) => {
  try {
    const file = event;
    console.log("Works!!");
    if (!file.bucket || !file.name) {
      throw new Error('Invalid event payload: missing bucket or name');
    }

    const bucketName = file.bucket;
    const fileName = file.name;

    let mimeType;
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (fileName.endsWith('.png')) {
      mimeType = 'image/png';
    } else {
      console.log(`Unsupported file type: ${fileName}`);
      return;
    }

    const fileUri = `gs://${bucketName}/${fileName}`;
    console.log(`Processing file at: ${fileUri}`);

    const vertex_ai = new VertexAI({
      project: 'mizuki-demo-joonix',
      location: 'asia-northeast1',
    });

    const generativeVisionModel = vertex_ai.preview.getGenerativeModel({
      model: 'gemini-1.5-pro-002',
      generation_config: {
        max_output_tokens: 8192,
        temperature: 0.1,
        top_p: 0.95,
        top_k: 40,
      },
    });

    // Step 1: Initial content generation
    const filePart = { fileData: { fileUri: fileUri, mimeType: mimeType } };
    const textPart = { text: `
        ## Goal
        * アップロードされた構成図を読み取って自動でTerrafomのコードのみを生成して下さい。
        * fileに追記する形式で記載して下さい
        * 不要な修飾を行う文字列は排除して下さい

        ## 構成図の詳細
        * プロジェクト名: mizuki-demo-joonix
        * リージョン: asia-northeast1
        * ベースとなるネットワーク:
            * VPC 名: default

        ## その他
        * 構成図に不足している情報がある場合は、妥当な値を想定してコードを生成してください。
        * 生成されたコードは、そのまま実行できる状態であることを確認してください。
    ` };
    const request1 = {
      contents: [{ role: 'user', parts: [textPart, filePart] }],
    };

    const streamingResult1 = await generativeVisionModel.generateContentStream(request1);
    const aggregatedResponse1 = await streamingResult1.response;
    const BaseResponse = aggregatedResponse1.candidates[0].content.parts[0].text;

    console.log('1st response:', BaseResponse);

    // Step 2: Formatting Terraform code
    const formattingRequest = {
        text: `
        以下の作成済みのベースとなるTerraformのコードに構成図から生成したコードを追記してmain.tfを完成させて下さい
        * プロジェクト名: mizuki-demo-joonix
        * リージョン: asia-northeast1
        
        ## 作成済みのベースとなるTerraformのコード
        terraform {
          required_providers {
            google = {
              source  = "hashicorp/google"
              version = "~> 4.0"
            }
          }
        }

        terraform {
          backend "gcs" {
            bucket = "tam-workbench-creator-state-bucket"
            prefix = "mizuki-demo-joonix"
          }
        }

        resource "google_storage_bucket" "tam_workbench_creator" {
          name          = "tam-workbench-creator-upload-bucket"
          project = "mizuki-demo-joonix" 
          location      = "asia-northeast1"
          storage_class = "STANDARD"
          force_destroy = true

          versioning {
            enabled = true
          }
        }
        
        ## 追記するTerraformのコード
        ${BaseResponse}
        `,
    };

    const request2 = {
      contents: [{ role: 'user', parts: [formattingRequest] }],
    };

    const streamingResult2 = await generativeVisionModel.generateContentStream(request2);
    const aggregatedResponse2 = await streamingResult2.response;
    const tfResponse = aggregatedResponse2.candidates[0].content.parts[0].text;

    console.log('2nd response:', tfResponse);

    // Step 3: Finalizing the Terraform code
    const createFileRequest = {
        text: `
        以下の作成済みのTerraformのコードmain.tfの本文を完成させて下さい。
        ソースコードのアウトプットのみを行って下さい、コードの先頭や末尾に不要な修飾文字は入れないで下さい。
        
        ${tfResponse}
        `,
    };

    const request3 = {
      contents: [{ role: 'user', parts: [createFileRequest] }],
    };

    const streamingResult3 = await generativeVisionModel.generateContentStream(request3);
    const aggregatedResponse3 = await streamingResult3.response;
    const finalTfCode = aggregatedResponse3.candidates[0].content.parts[0].text;

    console.log('3rd response:', finalTfCode);

    // GitHub設定
    const githubToken = process.env.GITHUB_TOKEN; // トークンを安全に保存してください
    const owner = "mizuki4i4"; // リポジトリの所有者
    const repo = "tam_workbech_creator"; // リポジトリ名
    const branchName = `update-terraform-${Date.now()}`; // 新しいブランチ名
    const baseBranch = "main"; // PRのベースとなるブランチ
    const filePath = "setup/main.tf"; // 更新するTerraformコードのファイルパス

    // GitHubクライアントを初期化
    const octokit = new Octokit({ auth: githubToken });

    // (1) メインブランチの最新SHAを取得
    const { data: branchData } = await octokit.repos.getBranch({
      owner,
      repo,
      branch: baseBranch,
    });
    const baseSha = branchData.commit.sha;

    // (2) 新しいブランチを作成
    await octokit.git.createRef({
      owner,
      repo,
      ref: `refs/heads/${branchName}`,
      sha: baseSha,
    });
    console.log(`Created new branch: ${branchName}`);

    // (3) ファイルの現在のコンテンツを取得
    let currentFileSha;
    try {
      const { data: fileData } = await octokit.repos.getContent({
        owner,
        repo,
        path: filePath,
        ref: baseBranch,
      });
      currentFileSha = fileData.sha;
    } catch (error) {
      if (error.status !== 404) throw error;
      console.log("Target file does not exist; creating a new one.");
    }

    // (4) ファイルを新しい内容で更新
    const updateMessage = "Update Terraform code using VertexAI -> Upload file: ${filePath}";
    const contentEncoded = Buffer.from(finalTfCode).toString("base64");

    await octokit.repos.createOrUpdateFileContents({
      owner,
      repo,
      path: filePath,
      message: updateMessage,
      content: contentEncoded,
      sha: currentFileSha, // 既存ファイルがない場合は `undefined` のままでOK
      branch: branchName,
    });
    console.log(`Upload file: ${filePath} in branch: ${branchName}`);
    const fileLink = "https://storage.googleapis.com/tam-workbench-creator-upload-bucket//${fileName}";


    // (5) PRを作成
    const prTitle = "Update Terraform Code via Cloud Functions";
    const prBody = `This PR updates the Terraform configuration file
    [${fileUri}](${fileUri})
    ![Image](${fileLink})
    `;

    const { data: prData } = await octokit.pulls.create({
      owner,
      repo,
      title: prTitle,
      body: prBody,
      head: branchName,
      base: baseBranch,
    });
    console.log(`Created Pull Request: ${prData.html_url}`);

  } catch (error) {
    console.error('Error processing file:', error);
  }
};