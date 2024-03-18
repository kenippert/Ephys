

import tensorflow as tf
import numpy as np
from tensorflow import keras, lite
# import scipy.io as spio

CLASS_NUM = 2 # drop and no drop
# HEIGHT = 240 #image size is 240 * 320 *3
# WIDTH = 320
HEIGHT = 80
WIDTH = 100

from keras.preprocessing.image import ImageDataGenerator

train_datagen = ImageDataGenerator(rescale = 1./255, #All the pixel values would be 0-1
                    shear_range = 0.2,
                    zoom_range = 0.2)

test_datagen = ImageDataGenerator(rescale = 1./255)

training_set = train_datagen.flow_from_directory('imageVer3/training_set',
                                                 target_size = (HEIGHT, WIDTH),
                                                 batch_size = 32)

test_set = test_datagen.flow_from_directory('imageVer3/test_set',
                                            target_size = (HEIGHT, WIDTH),
                                            batch_size = 32)





base = keras.applications.MobileNet(
    include_top=False,
    alpha=0.25,
    weights="imagenet",
    input_shape=(HEIGHT, WIDTH, 3)
)
base.trainable = False

x = base.output
flatten = keras.layers.Flatten()(x) 
predictions = keras.layers.Dense(CLASS_NUM, activation='softmax')(flatten)
model = keras.models.Model(inputs=base.input, outputs=predictions)


model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
model.fit(training_set, epochs = 100, validation_data = test_set)

# There is stuff in the example that saves a representative data set to the model? 
# I think they are just using noise right now, but I tried to switch to real data.
# def representative_dataset():
    # for _ in range(100):
        # data = np.random.rand(1, HEIGHT, WIDTH, 3)
        # yield [data.astype(np.float32)]

def representative_dataset():
    for _ in range(100):
        img = training_set.next()
        yield [np.array(img[0], dtype=np.float32)]

# mat2 = spio.loadmat('images3.mat',squeeze_me=True)
# images3 = mat2['images3']
# images3.astype(np.float32)
# print(images3.shape)

# Convert the tflite.
converter = lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
# converter.representative_dataset = images3
converter.target_spec.supported_ops = [lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8
tflite_quant_model = converter.convert()

# Save the model.
with open('trained.tflite', 'wb') as f:
  f.write(tflite_quant_model)