/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "ABI42_0_0LegacyViewManagerInteropViewEventEmitter.h"
#include <iostream>

namespace ABI42_0_0facebook {
namespace ABI42_0_0React {
void LegacyViewManagerInteropViewEventEmitter::dispatchEvent(
    std::string const &type,
    folly::dynamic const &payload) const {
  EventEmitter::dispatchEvent(type, payload);
}

} // namespace ABI42_0_0React
} // namespace ABI42_0_0facebook
