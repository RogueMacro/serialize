using System;
using Serialize;

namespace Serialize.Implementation
{
	interface IFormat
	{
		ISerializer CreateSerializer();
		IDeserializer CreateDeserializer();

		void Serialize<T>(ISerializer serializer, T value)
			where T : ISerializable;

		Result<T> Deserialize<T>(IDeserializer deserializer)
			where T : ISerializable;
	}
}