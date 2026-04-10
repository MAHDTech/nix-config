pub struct Client {
    pub base_url: String,
}

impl Client {
    pub fn new(base_url: String) -> Self {
        Self { base_url }
    }

    pub async fn list_models(&self) -> Result<Vec<String>, String> {
        Ok(vec!["gemma-4-e2b".to_string()])
    }
}
