package dev.assetpipeline.androidhost

/** How a photo handed over as bytes is decoded. The catalog's one-megapixel
 * bitmap budget still holds, but a customer document's product photo is
 * larger than that (1200 by 900 is already over it), so a photo decodes at
 * the power-of-two sample size that brings it within the budget and the
 * edge limit instead of being rejected; only a photo whose declared size is
 * absurd, or that the decoder cannot read, is refused. */
object ImageDecodePolicy {
    const val MAX_PIXELS = 1_048_576L
    const val MAX_EDGE = 4096
    /** The largest declared edge a photo may have before it is refused outright. */
    const val MAX_SOURCE_EDGE = 16_384

    /** True when the declared size is one this policy will decode at some sample size. */
    @JvmStatic fun accepts(width: Int, height: Int): Boolean =
        width in 1..MAX_SOURCE_EDGE && height in 1..MAX_SOURCE_EDGE

    /** The smallest power-of-two sample size at which the bitmap fits the
     * budget and the edge limit; 1 for a photo that already fits. */
    @JvmStatic fun sampleSize(width: Int, height: Int): Int {
        require(accepts(width, height)) { "photo size out of contract: $width x $height" }
        var sample = 1
        while ((width / sample).toLong() * (height / sample) > MAX_PIXELS || width / sample > MAX_EDGE || height / sample > MAX_EDGE) sample *= 2
        return sample
    }
}
