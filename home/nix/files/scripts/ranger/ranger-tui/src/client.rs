use serde::Deserialize;
use reqwest::Client as HttpClient;

#[derive(Deserialize, Debug)]
pub struct ModelList {
    pub data: Vec<ModelInfo>,
}

#[derive(Deserialize, Debug)]
pub struct ModelInfo {
    pub id: String,
}

pub struct Client {
    pub base_url: String,
    http: HttpClient,
}

impl Client {
    pub fn new(base_url: String) -> Self {
        Self {
            base_url,
            http: HttpClient::new(),
        }
    }

    pub async fn list_models(&self) -> Result<Vec<String>, String> {
        let url = format!("{}/v1/models", self.base_url);
        let resp = self.http.get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch models: {}", e))?;

        if !resp.status().is_success() {
            return Err(format!("API error: {}", resp.status()));
        }

        let model_list: ModelList = resp.json()
            .await
            .map_err(|e| format!("Failed to parse model list: {}", e))?;

        Ok(model_list.data.into_iter().map(|m| m.id).collect())
    }
}
