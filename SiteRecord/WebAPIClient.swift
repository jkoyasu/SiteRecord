import Foundation

enum WebAPIError: Error {
    case invalidRequest
    case noBodyContent
    case invalidBodyContent(reason: String)
}

///WebAPIへリクエストを行うクライアント
///
enum WebAPIClient{

    static let scheme = "http"
    static let host = "192.168.2.121"
    static let port = 3000
    static let path = "/record"
    
    /// POSTで新規投稿を送信するメソッド
    ///  -Parameters:
    ///  -message: 送信する音声データ
    ///  -handler: レスポンス取得後に実行するコールバック
    ///
    static func postMessage(webMessage: WebMessage,
        handler: @escaping (Result<WebMessage, WebAPIError>) -> Void){
        
        print("start postMessage")
            //2. リクエスト先のURLを指定して、URLオブジェクトを作成
            //TODO:2-1.URLComponentsオブジェクトを作成し、パスまでの部分を設定
        var components = URLComponents()
            components.scheme = self.scheme
            components.host = self.host
            components.port = self.port
            components.path = self.path
        
        ///TODO2-3 URLComponentsから　URLを作成
        var url = components.url!
        
        ///TODO3 URLRequestを作成
        var request = URLRequest(url:url)
       
        ///TODO3.1 URLRequestにリクエストメソッドとヘッダ、ボディを指定
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(webMessage)
        
        ///TODO: 4.URLSessionから、データ送受信を行うタスクを作成
        let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
            let result: Result<WebMessage,WebAPIError>
            
            defer{
                DispatchQueue.main.async {
                    handler(result)
                }
            }

            //レスポンスのすてータスコードが201(created)でない場合はfailure
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                      result = .failure(.invalidRequest)
                      
                      return
            }
            
            //レスポンスボディが取得できない場合はfailure
            guard let data = data else {
                result = .failure(.noBodyContent)
                return
            }
            
            //JSONのデコードが成功すればSuccess, 失敗した場合はfailure
            do{
                let decoder = JSONDecoder()
                let message = try decoder.decode(WebMessage.self, from: data)
                
                result = .success(message)
            }catch{
                result = .failure(.invalidBodyContent(reason: "\(error)"))
            }
        }
        //TODO: 5.タスクを実行
        task.resume()
        print("end postMessage")
        
    }
}
