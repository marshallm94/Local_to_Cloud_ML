import json
from pickle import dump
import pandas as pd
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

# fit model
X, y = make_classification(
        n_samples = 100000,
        n_informative = 10
        )

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.33, random_state=42)

model = RandomForestClassifier()
model.fit(X_train, y_train)

# save model
dump(model, open('prod_mode.joblib', 'wb'))

# save test set
test_df = pd.DataFrame(X_test)
test_df['outcome'] = y_test
dump(test_df, open('test_df.joblib', 'wb'))
