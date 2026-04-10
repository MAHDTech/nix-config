use burn::tensor::{backend::Backend, Device, Tensor};

/// Autoregressive cache for transformer keys and values.
pub struct AutoregressiveCache<B: Backend> {
    /// Tensor cache with shape `[batch_size, num_heads, max_seq_len, head_dim]`
    cache: Tensor<B, 4>,
    pub max_seq_len: usize,
    cur_seq_len: usize,
}

impl<B: Backend> AutoregressiveCache<B> {
    /// Creates a new empty cache.
    pub fn new(
        max_batch_size: usize,
        num_heads: usize,
        max_seq_len: usize,
        head_dim: usize,
        device: &Device<B>,
    ) -> Self {
        Self {
            cache: Tensor::zeros([max_batch_size, num_heads, max_seq_len, head_dim], device),
            max_seq_len,
            cur_seq_len: 0,
        }
    }

    /// Reset the cache state.
    pub fn reset(&mut self) {
        self.cache = Tensor::zeros(self.cache.shape(), &self.cache.device());
        self.cur_seq_len = 0;
    }

    /// Appends a new tensor slice to the cache and returns the current full prefix.
    pub fn forward(&mut self, tensor: Tensor<B, 4>) -> Tensor<B, 4> {
        let [batch_size, num_heads, seq_len, head_dim] = tensor.dims();
        let mut new_seq_len = self.cur_seq_len + seq_len;

        // Simple sliding window or truncation logic
        if new_seq_len > self.max_seq_len {
            // Shift cache to the left if full (simplistic for now)
            self.cur_seq_len = self.max_seq_len - seq_len;
            let prev_slice = self.cache.clone().slice([
                0..batch_size,
                0..num_heads,
                seq_len..self.max_seq_len,
                0..head_dim,
            ]);
            self.cache = self.cache.clone().slice_assign(
                [0..batch_size, 0..num_heads, 0..self.cur_seq_len, 0..head_dim],
                prev_slice,
            );
            new_seq_len = self.max_seq_len;
        }

        self.cache = self.cache.clone().slice_assign(
            [
                0..batch_size,
                0..num_heads,
                self.cur_seq_len..new_seq_len,
                0..head_dim,
            ],
            tensor,
        );

        self.cur_seq_len = new_seq_len;

        self.cache
            .clone()
            .slice([0..batch_size, 0..num_heads, 0..self.cur_seq_len, 0..head_dim])
    }

    /// Returns the cached sequence length.
    pub fn len(&self) -> usize {
        self.cur_seq_len
    }

    /// Returns true if the cache is completely empty.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

pub struct KeyValueCache<B: Backend> {
    pub key: AutoregressiveCache<B>,
    pub value: AutoregressiveCache<B>,
}

impl<B: Backend> KeyValueCache<B> {
    pub fn new(
        max_batch_size: usize,
        num_heads: usize,
        max_seq_len: usize,
        head_dim: usize,
        device: &Device<B>,
    ) -> Self {
        Self {
            key: AutoregressiveCache::new(max_batch_size, num_heads, max_seq_len, head_dim, device),
            value: AutoregressiveCache::new(max_batch_size, num_heads, max_seq_len, head_dim, device),
        }
    }

    pub fn forward(
        &mut self,
        key: Tensor<B, 4>,
        value: Tensor<B, 4>,
    ) -> (Tensor<B, 4>, Tensor<B, 4>) {
        let k = self.key.forward(key);
        let v = self.value.forward(value);
        (k, v)
    }

    pub fn len(&self) -> usize {
        self.key.len()
    }

    pub fn is_empty(&self) -> bool {
        self.key.is_empty()
    }

    pub fn reset(&mut self) {
        self.key.reset();
        self.value.reset();
    }
}
