using System;
using System.Collections;
using System.Reflection;

namespace Serialize.Util
{
	static class Util
	{
		public static bool IsPrimitiveStrict(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsPrimitive))
					return true;
			}

			if (type.IsEnum && type.IsUnion)
				return false;

			let generic = type as SpecializedGenericType;

			return type.IsPrimitive ||
				type.IsTypedPrimitive ||
				type.IsEnum ||
				type == typeof(String) ||
				type == typeof(DateTime) ||
				generic?.UnspecializedType == typeof(Nullable<>) &&
				IsPrimitiveStrict(generic.GetGenericArg(0));
		}

		public static bool IsPrimitive<TValue>(Type type, TValue object)
			where TValue : ISerializable
		{
			return IsPrimitiveStrict(object.__SerializeActualType);
		}

		public static bool IsListStrict(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsList))
					return true;
			}

			return (type is SpecializedGenericType &&
				(type as SpecializedGenericType).UnspecializedType == typeof(List<>)) ||
				type.IsArray;
		}

		public static bool IsList<T>(Type type, T object)
			where T : ISerializable
		{
			return IsListStrict(object.__SerializeActualType);
		}

		public static bool IsMapStrict(Type type)
		{
			return !IsPrimitiveStrict(type) && !IsListStrict(type);
		}

		public static bool IsMapStrict<T>()
			where T : ISerializable
		{
			return IsMapStrict(typeof(T));
		}

		public static bool IsMap<T>(Type type, T object)
			where T : ISerializable
		{
			return !IsPrimitive(typeof(T), object) && !IsList(typeof(T), object);
		}

		public static bool CanBePrimitiveOrMap(Type type)
		{
			return type.IsEnum && type.IsUnion;
		}
	}
}