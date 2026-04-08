use crate::config::Catalog;
use std::collections::HashMap;

use crate::config::{meta, google, qwen};

pub fn default_catalog() -> Catalog {
    let mut catalog = Catalog {
        models: HashMap::new(),
    };

    let mut text_models = Vec::new();
    text_models.extend(meta::models());
    text_models.extend(google::models());
    text_models.extend(qwen::models());

    catalog.models.insert("text".to_string(), text_models);
    catalog
}
