const { VertexAI } = require('@google-cloud/vertexai');
const { Storage } = require('@google-cloud/storage');

const storage = new Storage();

exports.main = async (event, context) => {
  try {
    const file = event;

    if (!file.bucket || !file.name) {
      throw new Error('Invalid event payload: missing bucket or name');
    }

    const bucketName = file.bucket;
    const fileName = file.name;

    // Vertex AI の設定
    const vertex_ai = new VertexAI({ 
      project: 'mizuki-demo-joonix', 
      location: 'asia-northeast1' 
    });
    const model = 'gemini-1.5-pro-002'; 
    const generativeModel = vertex_ai.preview.getGenerativeModel({
      model: model,
      generation_config: {
        "max_output_tokens": 8192,
        "temperature": 0.1,
        "top_p": 0.95,
        "top_k": 40
      },
    });

    // GCS からファイルデータを取得
    const bucket = storage.bucket(bucketName);
    const [contents] = await bucket.file(fileName).download();

    // ファイルの種類に応じてリクエストを作成
    let request;
    if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {  // 画像の場合
      request = {
        prompt: {
          text: `Uploaded image: ${contents.toString('base64')}`, 
        },
      };
    } else if (fileName.endsWith('.txt') || fileName.endsWith('.pdf')) {  // テキストの場合
      request = {
        prompt: {
          text: `Uploaded text: ${contents.toString()}`, 
        },
      };
    } else {
      console.log(`Unsupported file type: ${fileName}`);
      return;
    }

    // Vertex AI にリクエストを送信
    const [response] = await generativeModel.generateContent(request);

    // レスポンスを処理
    console.log('Generated text:', response.text); 

  } catch (error) {
    console.error('Error processing file:', error);
  }
};