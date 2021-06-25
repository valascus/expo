/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <folly/dynamic.h>
#include <ABI41_0_0React/components/activityindicator/primitives.h>

namespace ABI41_0_0facebook {
namespace ABI41_0_0React {

inline void fromRawValue(
    const RawValue &value,
    ActivityIndicatorViewSize &result) {
  auto string = (std::string)value;
  if (string == "large") {
    result = ActivityIndicatorViewSize::Large;
    return;
  }
  if (string == "small") {
    result = ActivityIndicatorViewSize::Small;
    return;
  }
  abort();
}

inline std::string toString(const ActivityIndicatorViewSize &value) {
  switch (value) {
    case ActivityIndicatorViewSize::Large:
      return "large";
    case ActivityIndicatorViewSize::Small:
      return "small";
  }
}

} // namespace ABI41_0_0React
} // namespace ABI41_0_0facebook
