use tokio::sync::mpsc;
use ranger_core::generate_stream;

#[derive(Debug, Clone)]
pub enum InferenceChunk {
    Token(String),
    Error(String),
    Done,
}

pub struct InferenceRequest {
    pub prompt: String,
    pub response_tx: mpsc::Sender<InferenceChunk>,
}

pub struct FifoQueue {
    sender: mpsc::Sender<InferenceRequest>,
}

impl FifoQueue {
    pub fn new() -> (Self, mpsc::Receiver<InferenceRequest>) {
        let (tx, rx) = mpsc::channel(100);
        (Self { sender: tx }, rx)
    }

    pub async fn submit(&self, prompt: String) -> Result<mpsc::Receiver<InferenceChunk>, String> {
        let (tx, rx) = mpsc::channel(100);
        let req = InferenceRequest {
            prompt,
            response_tx: tx,
        };
        self.sender.send(req).await.map_err(|e| e.to_string())?;
        Ok(rx)
    }
}

pub async fn background_worker(mut rx: mpsc::Receiver<InferenceRequest>) {
    log::info!("Background worker started.");

    while let Some(req) = rx.recv().await {
        log::info!("Processing request: {}", req.prompt);

        let (tx, mut core_rx) = mpsc::channel(100);
        let prompt = req.prompt.clone();

        // Spawn core generation as a task
        tokio::spawn(async move {
            if let Err(e) = generate_stream(prompt, tx).await {
                log::error!("Core generation failed: {}", e);
            }
        });

        // Forward core tokens to the requester
        while let Some(token) = core_rx.recv().await {
            if let Err(e) = req.response_tx.send(InferenceChunk::Token(token)).await {
                log::warn!("Could not send token chunk (requester dropped?): {}", e);
                break;
            }
        }

        // Mark completion
        let _ = req.response_tx.send(InferenceChunk::Done).await;
        log::info!("Request complete.");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_fifo_queue_streaming() {
        let (queue, rx) = FifoQueue::new();
        tokio::spawn(background_worker(rx));

        let mut rx = queue.submit("hello world".to_string()).await.unwrap();

        let mut tokens = Vec::new();
        while let Some(chunk) = rx.recv().await {
            match chunk {
                InferenceChunk::Token(t) => tokens.push(t),
                InferenceChunk::Done => break,
                InferenceChunk::Error(e) => panic!("Error: {}", e),
            }
        }

        // Core mock adds spaces: "hello  world " (or similar)
        assert!(tokens.concat().contains("hello"));
        assert!(tokens.concat().contains("world"));
    }
}
