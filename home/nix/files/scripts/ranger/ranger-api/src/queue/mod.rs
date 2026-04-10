use tokio::sync::{mpsc, oneshot};

pub struct InferenceRequest {
    pub prompt: String,
    pub response_tx: oneshot::Sender<InferenceResponse>,
}

pub struct InferenceResponse {
    pub text: String,
}

pub struct FifoQueue {
    sender: mpsc::Sender<InferenceRequest>,
}

impl FifoQueue {
    pub fn new() -> (Self, mpsc::Receiver<InferenceRequest>) {
        let (tx, rx) = mpsc::channel(100);
        (Self { sender: tx }, rx)
    }

    pub async fn submit(&self, prompt: String) -> Result<InferenceResponse, String> {
        let (tx, rx) = oneshot::channel();
        let req = InferenceRequest { prompt, response_tx: tx };
        self.sender.send(req).await.map_err(|e| e.to_string())?;
        rx.await.map_err(|e| e.to_string())
    }
}

pub async fn background_worker(mut rx: mpsc::Receiver<InferenceRequest>) {
    while let Some(req) = rx.recv().await {
        // Dummy inference processing
        let response = InferenceResponse { text: format!("Processed: {}", req.prompt) };
        let _ = req.response_tx.send(response);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_fifo_queue() {
        let (queue, rx) = FifoQueue::new();
        tokio::spawn(background_worker(rx));

        let res = queue.submit("hello".to_string()).await.unwrap();
        assert_eq!(res.text, "Processed: hello");
    }
}
